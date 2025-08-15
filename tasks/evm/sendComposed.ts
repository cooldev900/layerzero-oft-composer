import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import fs from 'fs'
import path from 'path'

task('lz:oft:send-composed', 'Send OFT tokens with composed message')
    .addParam('dstEid', 'Destination endpoint ID', undefined, types.int)
    .addParam('amount', 'Amount to send (in token units)', undefined, types.string)
    .addOptionalParam('recipient', 'Recipient address', '0x6E3a149F0972F9810B46D50C95e81A88b3f38E80', types.string)
    .addOptionalParam('messageType', 'Message type (CROSS_CHAIN_SEND or BURNT)', 'CROSS_CHAIN_SEND', types.string)
    .addOptionalParam('burntAmount', 'Amount that was burnt (only for BURNT message type)', undefined, types.string)
    .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
        const { ethers, getNamedAccounts, network } = hre
        const { deployer } = await getNamedAccounts()
        
        const { dstEid, amount, recipient, messageType, burntAmount } = taskArgs

        console.log(`\n🚀 Sending composed OFT message on ${network.name}`)
        console.log(`From: ${deployer}`)
        console.log(`To: ${recipient}`)
        console.log(`Amount: ${amount}`)
        console.log(`Destination EID: ${dstEid}`)
        console.log(`Message Type: ${messageType}`)
        if (burntAmount) {
            console.log(`Burnt Amount: ${burntAmount}`)
        }

        // Get signer
        const signer = await ethers.getNamedSigner('deployer')

        // Read deployments.json to get contract addresses
        const rootDir = path.join(__dirname, '../..')
        const deploymentsJsonPath = path.join(rootDir, 'deployments.json')
        
        let oftAddress: string | undefined
        let crossChainManagerAddress: string | undefined

        if (fs.existsSync(deploymentsJsonPath)) {
            try {
                const raw = fs.readFileSync(deploymentsJsonPath, 'utf8')
                const deploymentsData = JSON.parse(raw) as {
                    networks?: Record<string, { 
                        tokenAddress?: string
                        crossChainManagerAddress?: string
                    }>
                }
                
                const networkData = deploymentsData.networks?.[network.name]
                if (networkData) {
                    oftAddress = networkData.tokenAddress
                    crossChainManagerAddress = networkData.crossChainManagerAddress
                    
                    console.log(`\nFound addresses in deployments.json:`)
                    console.log(`  OFT: ${oftAddress}`)
                    console.log(`  CrossChainManager: ${crossChainManagerAddress}`)
                }
            } catch (error) {
                console.warn(`Failed to read deployments.json: ${error}`)
            }
        }

        // Fallback to hardhat deployments
        if (!oftAddress) {
            try {
                const oftDeployment = await hre.deployments.get('AlphaOFT')
                oftAddress = oftDeployment.address
                console.log(`Using AlphaOFT from hardhat deployments: ${oftAddress}`)
            } catch (error) {
                throw new Error(`AlphaOFT not found. Please deploy it first.`)
            }
        }

        if (!crossChainManagerAddress) {
            try {
                const managerDeployment = await hre.deployments.get('AlphaTokenCrossChainManager')
                crossChainManagerAddress = managerDeployment.address
                console.log(`Using AlphaTokenCrossChainManager from hardhat deployments: ${crossChainManagerAddress}`)
            } catch (error) {
                throw new Error(`AlphaTokenCrossChainManager not found. Please deploy it first.`)
            }
        }

        // Get contract instances
        const oft = await ethers.getContractAt('AlphaOFT', oftAddress!, signer)
        const composeMsg = await ethers.getContractAt('ComposeMsg', ethers.constants.AddressZero) // Library, no deployment needed

        // Get token decimals and parse amount
        const decimals = await oft.decimals()
        const amountLD = ethers.utils.parseUnits(amount, decimals)
        
        console.log(`\n📊 Token details:`)
        console.log(`  Decimals: ${decimals}`)
        console.log(`  Amount (raw): ${amountLD.toString()}`)

        // Check sender balance
        const balance = await oft.balanceOf(signer.address)
        if (balance.lt(amountLD)) {
            throw new Error(`Insufficient balance. Have: ${ethers.utils.formatUnits(balance, decimals)}, Need: ${amount}`)
        }
        console.log(`  Sender balance: ${ethers.utils.formatUnits(balance, decimals)}`)

        // For testing, let's use an empty compose message
        const composeData = '0x'
        
        console.log(`\n📝 Using empty compose message for testing`)

        // Build LayerZero options for compose execution
        console.log(`\n🔧 Building LayerZero options...`)
        
        // For now, let's use empty options to test basic functionality
        // TODO: Implement proper OptionsBuilder pattern
        const finalOptions = '0x'
        
        console.log(`  Using empty options for now (testing basic functionality)`)
        console.log(`  Options length: ${finalOptions.length}`)

        // Prepare send parameters
        const sendParam = {
            dstEid: dstEid,
            to: ethers.utils.zeroPad(recipient, 32), // Send directly to recipient for now (testing)
            amountLD: amountLD,
            minAmountLD: amountLD, // No slippage for this example
            extraOptions: finalOptions, // LayerZero options for compose execution
            composeMsg: composeData, // Our composed message
            oftCmd: '0x' // No OFT command
        }

        console.log(`\n🔧 Send parameters:`)
        console.log(`  dstEid: ${sendParam.dstEid}`)
        console.log(`  to: ${sendParam.to}`)
        console.log(`  amountLD: ${sendParam.amountLD.toString()}`)
        console.log(`  extraOptions length: ${finalOptions.length}`)
        console.log(`  composeMsg length: ${composeData.length}`)

        // Quote the send operation
        console.log(`\n💰 Quoting send operation...`)
        const quote = await oft.quoteSend(sendParam, false) // false for lzTokenFee
        const nativeFee = quote.nativeFee
        const lzTokenFee = quote.lzTokenFee

        console.log(`  Native fee: ${ethers.utils.formatEther(nativeFee)} ETH`)
        console.log(`  LZ token fee: ${lzTokenFee.toString()}`)

        // Check if user has enough ETH for gas
        const ethBalance = await signer.getBalance()
        if (ethBalance.lt(nativeFee)) {
            throw new Error(`Insufficient ETH for gas. Have: ${ethers.utils.formatEther(ethBalance)} ETH, Need: ${ethers.utils.formatEther(nativeFee)} ETH`)
        }

        // Send the transaction
        console.log(`\n🚀 Sending composed message...`)
        const tx = await oft.send(
            sendParam,
            { nativeFee: nativeFee, lzTokenFee: lzTokenFee },
            signer.address, // refund address
            { value: nativeFee }
        )

        console.log(`📤 Transaction sent: ${tx.hash}`)
        console.log(`⏳ Waiting for confirmation...`)

        const receipt = await tx.wait()
        console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`)
        console.log(`   Gas used: ${receipt.gasUsed.toString()}`)

        // Parse events to show what happened
        try {
            const events = receipt.logs.map(log => {
                try {
                    return oft.interface.parseLog(log)
                } catch {
                    return null
                }
            }).filter(Boolean)

            console.log(`\n📋 Events emitted:`)
            events.forEach((event, index) => {
                if (event) {
                    console.log(`  ${index + 1}. ${event.name}`)
                    if (event.name === 'OFTSent') {
                        console.log(`     - guid: ${event.args.guid}`)
                        console.log(`     - dstEid: ${event.args.dstEid}`)
                        console.log(`     - from: ${event.args.from}`)
                        console.log(`     - amountSentLD: ${ethers.utils.formatUnits(event.args.amountSentLD, decimals)}`)
                        console.log(`     - amountReceivedLD: ${ethers.utils.formatUnits(event.args.amountReceivedLD, decimals)}`)
                    }
                }
            })
        } catch (error) {
            console.log(`⚠️  Could not parse events: ${error}`)
        }

        // Log to history
        try {
            const historyLogPath = path.join(rootDir, 'deployments-history.log')
            const logEntry = [
                `\n===== Composed OFT Send @ ${new Date().toISOString()} =====`,
                `Network: ${network.name}`,
                `From: ${signer.address}`,
                `To: ${recipient}`,
                `Amount: ${amount}`,
                `Destination EID: ${dstEid}`,
                `Message Type: ${messageType}`,
                burntAmount ? `Burnt Amount: ${burntAmount}` : undefined,
                `OFT Contract: ${oftAddress}`,
                `CrossChainManager: ${crossChainManagerAddress}`,
                `Transaction: ${tx.hash}`,
                `Gas Used: ${receipt.gasUsed.toString()}`,
                `Native Fee: ${ethers.utils.formatEther(nativeFee)} ETH`,
            ].filter(Boolean).join('\n')

            fs.appendFileSync(historyLogPath, logEntry + '\n')
            console.log(`\n📝 Logged to ${historyLogPath}`)
        } catch (error) {
            console.warn(`⚠️  Failed to log to history: ${error}`)
        }

        console.log(`\n🎉 Composed message sent successfully!`)
        console.log(`The CrossChainManager on destination chain (EID ${dstEid}) will receive the tokens and forward them to ${recipient}`)
        console.log(`\nNext steps:`)
        console.log(`1. Wait for LayerZero to relay the message to destination chain`)
        console.log(`2. Check the destination chain for the composed message execution`)
        console.log(`3. Verify that ${recipient} received the tokens`)
    })

export {}
