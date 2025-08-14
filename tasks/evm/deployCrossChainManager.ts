import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

task('lz:deploy:cross-chain-manager', 'Deploy AlphaTokenCrossChainManager upgradeable contract')
    .addOptionalParam('endpoint', 'LayerZero endpoint address', undefined, types.string)
    .addOptionalParam('trustedOft', 'Trusted OFT contract address', undefined, types.string)
    .addOptionalParam('owner', 'Owner address for the contract', undefined, types.string)
    .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
        const { ethers, deployments, getNamedAccounts, network } = hre
        const { deployer } = await getNamedAccounts()

        console.log(`\n🚀 Deploying AlphaTokenCrossChainManager on ${network.name}`)
        console.log(`Deployer: ${deployer}`)

        // Run the deploy script
        await hre.run('deploy', {
            tags: 'AlphaTokenCrossChainManager',
            network: network.name
        })

        console.log(`\n✅ AlphaTokenCrossChainManager deployment completed!`)
        console.log(`Check deployments.json for the deployed addresses.`)
    })

export {}
