import assert from 'assert'
import fs from 'fs'
import path from 'path'

import { type DeployFunction } from 'hardhat-deploy/types'

const contractName = 'AlphaOFT'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    // This is an external deployment pulled in from @layerzerolabs/lz-evm-sdk-v2
    //
    // @layerzerolabs/toolbox-hardhat takes care of plugging in the external deployments
    // from @layerzerolabs packages based on the configuration in your hardhat config
    //
    // For this to work correctly, your network config must define an eid property
    // set to `EndpointId` as defined in @layerzerolabs/lz-definitions
    //
    // For example:
    //
    // networks: {
    //   fuji: {
    //     ...
    //     eid: EndpointId.AVALANCHE_V2_TESTNET
    //   }
    // }
    // Resolve EndpointV2 address from deployments.json if present for this network; fallback to external deployment
    let endpointAddress: string | undefined
    try {
        const rootDir = path.join(__dirname, '..')
        const deploymentsJsonPath = path.join(rootDir, 'deployments.json')
        if (fs.existsSync(deploymentsJsonPath)) {
            const raw = fs.readFileSync(deploymentsJsonPath, 'utf8')
            const json = JSON.parse(raw) as { networks?: Record<string, { lzEndpoint?: string }> }
            endpointAddress = json.networks?.[hre.network.name]?.lzEndpoint
        }
    } catch (_) {}
    if (!endpointAddress) {
        const endpointV2Deployment = await hre.deployments.get('EndpointV2')
        endpointAddress = endpointV2Deployment.address
    }

    // Resolve token name/symbol from deployments.json metadata (fallback to defaults)
    let tokenName = 'MyOFT'
    let tokenSymbol = 'MOFT'
    try {
        const rootDir = path.join(__dirname, '..')
        const deploymentsJsonPath = path.join(rootDir, 'deployments.json')
        if (fs.existsSync(deploymentsJsonPath)) {
            const raw = fs.readFileSync(deploymentsJsonPath, 'utf8')
            const json = JSON.parse(raw) as { metadata?: { tokenName?: string; tokenSymbol?: string } }
            tokenName = json.metadata?.tokenName || tokenName
            tokenSymbol = json.metadata?.tokenSymbol || tokenSymbol
        }
    } catch (_) {}

    const { address } = await deploy(contractName, {
        from: deployer,
        args: [
            tokenName, // name
            tokenSymbol, // symbol
            endpointAddress, // LayerZero's EndpointV2 address
            deployer, // owner
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    })

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)

    // Attempt contract verification (if supported/configured)
    try {
        await hre.run('verify:verify', { address, constructorArguments: [tokenName, tokenSymbol, endpointAddress, deployer] })
        console.log(`[verify] Submitted verification for ${address} on ${hre.network.name}`)
    } catch (e: any) {
        console.warn(`[verify] Skipped or failed: ${e?.message ?? e}`)
    }

    // Update deployments.json tokenAddress and append to deployments-history.log (with simple file lock)
    try {
        const rootDir = path.join(__dirname, '..')
        const deploymentsJsonPath = path.join(rootDir, 'deployments.json')
        const historyLogPath = path.join(rootDir, 'deployments-history.log')
        const lockPath = deploymentsJsonPath + '.lock'

        async function sleep(ms: number) {
            return new Promise((resolve) => setTimeout(resolve, ms))
        }

        async function acquireLock(timeoutMs = 30000, pollMs = 200): Promise<boolean> {
            const start = Date.now()
            while (Date.now() - start < timeoutMs) {
                try {
                    const fd = fs.openSync(lockPath, 'wx')
                    fs.writeFileSync(fd, String(process.pid))
                    fs.closeSync(fd)
                    return true
                } catch {
                    // lock held by another process
                    await sleep(pollMs)
                }
            }
            return false
        }

        function releaseLock() {
            try { fs.unlinkSync(lockPath) } catch {}
        }

        // Attempt to extract a tx hash from the saved deployment artifact (if present)
        let txHash: string | undefined
        try {
            const deploymentRecord = await hre.deployments.get(contractName)
            // hardhat-deploy stores tx hash either on transactionHash or in receipt
            txHash = (deploymentRecord as any).transactionHash || (deploymentRecord as any).receipt?.transactionHash
        } catch (_) {
            // ignore
        }

        if (fs.existsSync(deploymentsJsonPath)) {
            const locked = await acquireLock()
            if (!locked) {
                console.warn(`[deployments.json] Could not acquire lock; skipping update`)
            } else {
                try {
                    // Re-read latest file to avoid clobbering concurrent writers
                    const latestRaw = fs.readFileSync(deploymentsJsonPath, 'utf8')
                    const latest = JSON.parse(latestRaw) as {
                        version?: string
                        lastUpdated?: string
                        networks?: Record<string, { tokenAddress?: string; deployer?: string; lzEndpoint?: string; [k: string]: unknown }>
                    }
                    latest.networks = latest.networks || {}
                    const key = hre.network.name
                    latest.networks[key] = {
                        ...(latest.networks[key] || {}),
                        tokenAddress: address,
                        deployer,
                        lzEndpoint: endpointAddress,
                    }
                    latest.lastUpdated = new Date().toISOString()
                    const tmpPath = deploymentsJsonPath + '.tmp.' + Date.now()
                    fs.writeFileSync(tmpPath, JSON.stringify(latest, null, 2))
                    fs.renameSync(tmpPath, deploymentsJsonPath)
                    console.log(`[deployments.json] Updated tokenAddress for '${key}' => ${address}`)
                } finally {
                    releaseLock()
                }
            }
        } else {
            console.warn(`[deployments.json] Not found at ${deploymentsJsonPath}; skipping update`)
        }

        const lines = [
            `Deployed ${contractName} on ${hre.network.name}`,
            `Address: ${address}`,
            txHash ? `TxHash: ${txHash}` : undefined,
            `Deployer: ${deployer}`,
        ].filter(Boolean)
        const header = `\n===== ${contractName} deploy @ ${new Date().toISOString()} =====\n`
        fs.appendFileSync(historyLogPath, header + lines.join('\n') + '\n')
        console.log(`[history] Appended entry to ${historyLogPath}`)
    } catch (e: any) {
        console.warn(`[post-deploy bookkeeping] Skipped or failed: ${e?.message ?? e}`)
    }
}

deploy.tags = [contractName]

export default deploy
