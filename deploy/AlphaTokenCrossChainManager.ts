import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import fs from 'fs'
import path from 'path'

const contractName = 'AlphaTokenCrossChainManager'

const deploy: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { getNamedAccounts, deployments, network, ethers } = hre
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    console.log(`Deploying ${contractName} on network: ${network.name}`)
    console.log(`Deployer: ${deployer}`)

    // Read deployments.json to get endpoint and trustedOFT addresses
    const rootDir = path.join(__dirname, '..')
    const deploymentsJsonPath = path.join(rootDir, 'deployments.json')
    
    let endpointAddress: string | undefined
    let trustedOFTAddress: string | undefined
    let ownerAddress = deployer // Default to deployer

    if (fs.existsSync(deploymentsJsonPath)) {
        try {
            const raw = fs.readFileSync(deploymentsJsonPath, 'utf8')
            const deploymentsData = JSON.parse(raw) as {
                networks?: Record<string, { 
                    lzEndpoint?: string
                    tokenAddress?: string
                    owner?: string
                }>
            }
            
            const networkData = deploymentsData.networks?.[network.name]
            if (networkData) {
                endpointAddress = networkData.lzEndpoint
                trustedOFTAddress = networkData.tokenAddress
                ownerAddress = networkData.owner || deployer
                
                console.log(`Found network config in deployments.json:`)
                console.log(`  Endpoint: ${endpointAddress}`)
                console.log(`  TrustedOFT: ${trustedOFTAddress}`)
                console.log(`  Owner: ${ownerAddress}`)
            }
        } catch (error) {
            console.warn(`Failed to read deployments.json: ${error}`)
        }
    }

    // Fallback to hardhat deployments if not found in deployments.json
    if (!endpointAddress) {
        try {
            const endpointV2Deployment = await deployments.get('EndpointV2')
            endpointAddress = endpointV2Deployment.address
            console.log(`Using EndpointV2 from hardhat deployments: ${endpointAddress}`)
        } catch (error) {
            throw new Error(`LayerZero endpoint not found. Please ensure it's deployed or specified in deployments.json`)
        }
    }

    if (!trustedOFTAddress) {
        try {
            const alphaOFTDeployment = await deployments.get('AlphaOFT')
            trustedOFTAddress = alphaOFTDeployment.address
            console.log(`Using AlphaOFT from hardhat deployments: ${trustedOFTAddress}`)
        } catch (error) {
            throw new Error(`AlphaOFT not found. Please deploy AlphaOFT first or specify tokenAddress in deployments.json`)
        }
    }

    console.log(`\nDeployment parameters:`)
    console.log(`  Endpoint: ${endpointAddress}`)
    console.log(`  TrustedOFT: ${trustedOFTAddress}`)
    console.log(`  Owner: ${ownerAddress}`)

    // Deploy implementation contract
    console.log(`\nDeploying ${contractName} implementation...`)
    const implementationResult = await deploy(`${contractName}_Implementation`, {
        contract: contractName,
        from: deployer,
        args: [], // No constructor args for upgradeable contract
        log: true,
        skipIfAlreadyDeployed: false,
    })

    // Prepare initialization data
    const initializeInterface = new ethers.utils.Interface([
        'function initialize(address _endpoint, address _trustedOFT, address _owner)'
    ])
    const initializeData = initializeInterface.encodeFunctionData('initialize', [
        endpointAddress,
        trustedOFTAddress,
        ownerAddress
    ])

    // Deploy proxy contract
    console.log(`\nDeploying ${contractName} proxy...`)
    const proxyResult = await deploy(contractName, {
        contract: 'ERC1967ProxyWrapper',
        from: deployer,
        args: [implementationResult.address, initializeData],
        log: true,
        skipIfAlreadyDeployed: false,
    })

    const proxyAddress = proxyResult.address
    const implementationAddress = implementationResult.address

    console.log(`\n✅ ${contractName} deployed successfully!`)
    console.log(`  Implementation: ${implementationAddress}`)
    console.log(`  Proxy: ${proxyAddress}`)

    // Verify contracts
    if (network.name !== 'hardhat' && network.name !== 'localhost') {
        console.log(`\n🔍 Verifying contracts...`)
        
        try {
            // Verify implementation
            await hre.run('verify:verify', {
                address: implementationAddress,
                constructorArguments: [],
            })
            console.log(`✅ Implementation verified: ${implementationAddress}`)
        } catch (error: any) {
            if (error.message.includes('Already Verified')) {
                console.log(`✅ Implementation already verified: ${implementationAddress}`)
            } else if (error.message.includes('does not have bytecode')) {
                console.log(`⚠️  Implementation verification skipped: Contract not yet propagated`)
            } else {
                console.warn(`⚠️  Implementation verification failed: ${error.message}`)
            }
        }

        try {
            // Verify proxy
            await hre.run('verify:verify', {
                address: proxyAddress,
                constructorArguments: [implementationAddress, initializeData],
            })
            console.log(`✅ Proxy verified: ${proxyAddress}`)
        } catch (error: any) {
            if (error.message.includes('Already Verified')) {
                console.log(`✅ Proxy already verified: ${proxyAddress}`)
            } else if (error.message.includes('does not have bytecode')) {
                console.log(`⚠️  Proxy verification skipped: Contract not yet propagated`)
            } else {
                console.warn(`⚠️  Proxy verification failed: ${error.message}`)
            }
        }
    }

    // Update deployments.json and log transaction history
    try {
        const historyLogPath = path.join(rootDir, 'deployments-history.log')
        const lockPath = deploymentsJsonPath + '.lock'

        // Simple file locking mechanism
        const acquireLock = async (timeout = 30000): Promise<boolean> => {
            const start = Date.now()
            while (Date.now() - start < timeout) {
                try {
                    fs.writeFileSync(lockPath, process.pid.toString(), { flag: 'wx' })
                    return true
                } catch {
                    await new Promise(resolve => setTimeout(resolve, 100))
                }
            }
            return false
        }

        const releaseLock = () => {
            try {
                fs.unlinkSync(lockPath)
            } catch {}
        }

        if (fs.existsSync(deploymentsJsonPath)) {
            const locked = await acquireLock()
            if (!locked) {
                console.warn(`[deployments.json] Could not acquire lock; skipping update`)
            } else {
                try {
                    // Re-read latest deployments.json to avoid clobbering concurrent writes
                    const latestRaw = fs.readFileSync(deploymentsJsonPath, 'utf8')
                    const latest = JSON.parse(latestRaw) as {
                        version?: string
                        lastUpdated?: string
                        networks?: Record<string, any>
                    }
                    
                    latest.networks = latest.networks || {}
                    const key = network.name
                    latest.networks[key] = {
                        ...(latest.networks[key] || {}),
                        crossChainManagerAddress: proxyAddress,
                        crossChainManagerImplementation: implementationAddress,
                        lzEndpoint: endpointAddress,
                        tokenAddress: trustedOFTAddress,
                        owner: ownerAddress,
                    }
                    latest.lastUpdated = new Date().toISOString()
                    
                    const tmpPath = deploymentsJsonPath + '.tmp.' + Date.now()
                    fs.writeFileSync(tmpPath, JSON.stringify(latest, null, 2))
                    fs.renameSync(tmpPath, deploymentsJsonPath)
                    console.log(`[deployments.json] Updated crossChainManagerAddress for '${key}' => ${proxyAddress}`)
                } finally {
                    releaseLock()
                }
            }
        } else {
            console.warn(`[deployments.json] Not found at ${deploymentsJsonPath}; skipping update`)
        }

        // Log transaction history
        const deploymentInfo = [
            `\n===== ${contractName} deployment @ ${new Date().toISOString()} =====`,
            `Network: ${network.name}`,
            `Implementation Address: ${implementationAddress}`,
            `Proxy Address: ${proxyAddress}`,
            implementationResult.transactionHash ? `Implementation TxHash: ${implementationResult.transactionHash}` : undefined,
            proxyResult.transactionHash ? `Proxy TxHash: ${proxyResult.transactionHash}` : undefined,
            `Deployer: ${deployer}`,
            `Initialization parameters:`,
            `  - Endpoint: ${endpointAddress}`,
            `  - TrustedOFT: ${trustedOFTAddress}`,
            `  - Owner: ${ownerAddress}`,
        ].filter(Boolean).join('\n')

        fs.appendFileSync(historyLogPath, deploymentInfo + '\n')
        console.log(`[history] Appended deployment entry to ${historyLogPath}`)

    } catch (error: any) {
        console.warn(`[post-deploy bookkeeping] Skipped or failed: ${error?.message ?? error}`)
    }

    // Test the deployed contract
    try {
        console.log(`\n🧪 Testing deployed contract...`)
        const manager = await ethers.getContractAt(contractName, proxyAddress)
        
        const version = await manager.version()
        const endpoint = await manager.endpoint()
        const trustedOFT = await manager.trustedOFT()
        const owner = await manager.owner()
        const totalProcessed = await manager.totalProcessed()
        const isPaused = await manager.paused()

        console.log(`✅ Contract test successful:`)
        console.log(`  Version: ${version}`)
        console.log(`  Endpoint: ${endpoint}`)
        console.log(`  TrustedOFT: ${trustedOFT}`)
        console.log(`  Owner: ${owner}`)
        console.log(`  TotalProcessed: ${totalProcessed}`)
        console.log(`  Paused: ${isPaused}`)
    } catch (error: any) {
        console.warn(`⚠️  Contract test failed: ${error.message}`)
    }

    console.log(`\n🎉 Deployment completed!`)
    console.log(`Use this address for interactions: ${proxyAddress}`)
}

deploy.tags = [contractName]
deploy.dependencies = [] // We handle dependencies manually by reading deployments.json

export default deploy
