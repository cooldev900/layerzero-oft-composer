import { task, types } from 'hardhat/config'

task('lz:oft:mint', 'Mints MyOFT tokens to an address')
    .addParam('to', 'Recipient address', undefined, types.string)
    .addParam('amount', 'Amount in human units (e.g. 10000)', undefined, types.string)
    .setAction(async ({ to, amount }, hre) => {
        const signer = await hre.ethers.getNamedSigner('deployer')
        const myOft = await hre.ethers.getContractAt('MyOFT', (await hre.deployments.get('MyOFT')).address, signer)
        const decimals: number = await myOft.decimals()
        const value = hre.ethers.utils.parseUnits(amount, decimals)
        const tx = await myOft.mint(to, value)
        const receipt = await tx.wait()
        console.log('Minted', amount, 'to', to, 'tx:', receipt.transactionHash)
    })


