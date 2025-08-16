import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { EndpointId, getNetworkForChainId } from '@layerzerolabs/lz-definitions'
import fs from 'fs'
import path from 'path'

interface NetworkData {
    network: string
    chainId: string
    tokenAddress?: string
    crossChainManagerAddress?: string
    lzEndpoint?: string
    eid?: number
}

interface DeploymentsData {
    networks: Record<string, NetworkData>
}

task('lz:oft:set-cross-chain-managers', 'Set cross-chain manager addresses for all networks')
    .addOptionalParam('dryRun', 'Preview changes without executing transactions', false, types.boolean)
    .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
        const { dryRun } = taskArgs

        // Read deployments.json
        const rootDir = path.join(__dirname, '../..')
        const deploymentsJsonPath = path.join(rootDir, 'deployments.json')
        
        if (!fs.existsSync(deploymentsJsonPath)) {
            throw new Error(`deployments.json not found at ${deploymentsJsonPath}`)
        }

        const deploymentsData: DeploymentsData = JSON.parse(fs.readFileSync(deploymentsJsonPath, 'utf8'))
        
        // Get current network data
        const currentNetworkName = hre.network.name
        const currentNetworkData = deploymentsData.networks[currentNetworkName]
        
        if (!currentNetworkData) {
            throw new Error(`Network ${currentNetworkName} not found in deployments.json`)
        }

        if (!currentNetworkData.tokenAddress) {
            throw new Error(`No tokenAddress found for ${currentNetworkName} in deployments.json`)
        }

        console.log(`\n🔧 Setting cross-chain managers for AlphaOFT on ${currentNetworkName}`)
        console.log(`AlphaOFT address: ${currentNetworkData.tokenAddress}`)

        // Get signer
        const signer = await hre.ethers.getNamedSigner('deployer')
        
        // Get AlphaOFT contract
        const alphaOFT = await hre.ethers.getContractAt('AlphaOFT', currentNetworkData.tokenAddress)

        // Collect all destination networks that have cross-chain managers
        const destinationNetworks: Array<{
            networkName: string
            eid: number
            managerAddress: string
        }> = []

        for (const [networkName, networkData] of Object.entries(deploymentsData.networks)) {
            // Skip current network
            if (networkName === currentNetworkName) continue
            
            // Skip networks without cross-chain managers
            if (!networkData.crossChainManagerAddress || networkData.crossChainManagerAddress === '0x0000000000000000000000000000000000000000') {
                console.log(`⚠️  Skipping ${networkName}: No cross-chain manager address`)
                continue
            }

            // Get endpoint ID from destination network's chainId using LayerZero definitions
            const eid = networkData.eid
                
            if (!eid) {
                console.log(`⚠️  Skipping ${networkName}: No EID found in deployments.json`)
                continue
            }

            destinationNetworks.push({
                networkName,
                eid,
                managerAddress: networkData.crossChainManagerAddress
            })
        }

        if (destinationNetworks.length === 0) {
            console.log(`\n⚠️  No destination networks with cross-chain managers found`)
            return
        }

        console.log(`\n📋 Found ${destinationNetworks.length} destination networks:`)
        destinationNetworks.forEach(dest => {
            console.log(`  ${dest.networkName} (EID: ${dest.eid}) -> ${dest.managerAddress}`)
        })

        if (dryRun) {
            console.log(`\n🔍 DRY RUN - No transactions will be executed`)
            console.log(`\nTransactions that would be executed:`)
            for (const dest of destinationNetworks) {
                console.log(`  setCrossChainManager(${dest.eid}, "${dest.managerAddress}")`)
            }
            return
        }

        // Execute transactions
        console.log(`\n🚀 Executing transactions...`)
        
        for (const dest of destinationNetworks) {
            try {
                console.log(`\n📤 Setting manager for ${dest.networkName} (EID: ${dest.eid})...`)
                
                // Check if manager is already set
                const currentManager = await alphaOFT.crossChainManagers(dest.eid)
                if (currentManager.toLowerCase() === dest.managerAddress.toLowerCase()) {
                    console.log(`  ✅ Already set correctly`)
                    continue
                }

                const tx = await alphaOFT.connect(signer as any).setCrossChainManager(dest.eid, dest.managerAddress)
                console.log(`  📤 Transaction sent: ${tx.hash}`)
                
                const receipt = await tx.wait()
                console.log(`  ✅ Confirmed in block ${receipt.blockNumber}`)
                console.log(`  💰 Gas used: ${receipt.gasUsed.toString()}`)
                
            } catch (error) {
                console.error(`  ❌ Failed to set manager for ${dest.networkName}:`, error)
                // Continue with other networks
            }
        }

        // Verify all settings
        console.log(`\n🔍 Verifying settings...`)
        for (const dest of destinationNetworks) {
            try {
                const setManager = await alphaOFT.crossChainManagers(dest.eid)
                if (setManager.toLowerCase() === dest.managerAddress.toLowerCase()) {
                    console.log(`  ✅ ${dest.networkName} (EID: ${dest.eid}): Correctly set`)
                } else {
                    console.log(`  ❌ ${dest.networkName} (EID: ${dest.eid}): Mismatch`)
                    console.log(`    Expected: ${dest.managerAddress}`)
                    console.log(`    Actual: ${setManager}`)
                }
            } catch (error) {
                console.log(`  ⚠️  ${dest.networkName} (EID: ${dest.eid}): Could not verify`)
            }
        }

        console.log(`\n✅ Cross-chain manager setup completed!`)
        console.log(`\nNext steps:`)
        console.log(`1. Run this task on other networks to set their cross-chain managers`)
        console.log(`2. Ensure LayerZero peers are configured using 'lz:oapp:config:set'`)
        console.log(`3. Test cross-chain transfers using 'lz:oft:send-composed'`)
    })

export {}
