import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import fs from 'fs'
import path from 'path'
import { createGetHreByEid } from '@layerzerolabs/devtools-evm-hardhat'
import { ChainType, endpointIdToChainType, endpointIdToNetwork } from '@layerzerolabs/lz-definitions'
import { getLayerZeroScanLink } from '../solana'

task('lz:oft:send-composed', 'Send OFT tokens with composed message')
    .addParam('srcEid', 'Source endpoint ID', undefined, types.int)
    .addParam('dstEid', 'Destination endpoint ID', undefined, types.int)
    .addParam('amount', 'Amount to send (in token units)', undefined, types.string)
    .addOptionalParam('recipient', 'Recipient address', '0x6E3a149F0972F9810B46D50C95e81A88b3f38E80', types.string)
    .addOptionalParam('messageType', 'Message type (CROSS_CHAIN_SEND or BURNT)', 'CROSS_CHAIN_SEND', types.string)
    .addOptionalParam('payInLzToken', 'Pay fees in LZ tokens', false, types.boolean)
    .addOptionalParam('extraOptions', 'Extra LayerZero options (hex)', '0x', types.string)
    .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
        const { srcEid, dstEid, amount, recipient, messageType, payInLzToken, extraOptions } = taskArgs

        // Validate that srcEid is an EVM chain
        if (endpointIdToChainType(srcEid) !== ChainType.EVM) {
            throw new Error(`Source EID ${srcEid} (${endpointIdToNetwork(srcEid)}) is not an EVM chain. This task only supports EVM source chains.`)
        }

        // Get HRE for the source endpoint ID
        const getHreByEid = createGetHreByEid(hre)
        let srcEidHre: HardhatRuntimeEnvironment
        try {
            srcEidHre = await getHreByEid(srcEid)
        } catch (error) {
            throw new Error(`Failed to get HRE for source EID ${srcEid} (${endpointIdToNetwork(srcEid)}): ${error}`)
        }

        // Use the source HRE for all operations
        const { ethers, getNamedAccounts, network } = srcEidHre
        const { deployer } = await getNamedAccounts()

        console.log(`\n🚀 Sending composed OFT message on ${network.name}`)
        console.log(`From: ${deployer}`)
        console.log(`To: ${recipient}`)
        console.log(`Amount: ${amount}`)
        console.log(`Source EID: ${srcEid}`)
        console.log(`Destination EID: ${dstEid}`)
        console.log(`Message Type: ${messageType}`)
        console.log(`Pay in LZ Token: ${payInLzToken}`)
        console.log(`Extra Options: ${extraOptions}`)

        // Get signer from the source HRE
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
                const oftDeployment = await srcEidHre.deployments.get('AlphaOFT')
                oftAddress = oftDeployment.address
                console.log(`Using AlphaOFT from hardhat deployments: ${oftAddress}`)
            } catch (error) {
                throw new Error(`AlphaOFT not found. Please deploy it first.`)
            }
        }

        if (!crossChainManagerAddress) {
            try {
                const managerDeployment = await srcEidHre.deployments.get('AlphaTokenCrossChainManager')
                crossChainManagerAddress = managerDeployment.address
                console.log(`Using AlphaTokenCrossChainManager from hardhat deployments: ${crossChainManagerAddress}`)
            } catch (error) {
                throw new Error(`AlphaTokenCrossChainManager not found. Please deploy it first.`)
            }
        }

        // Get contract instances
        const oft = await ethers.getContractAt('AlphaOFT', oftAddress!)

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

        // Transfer tokens from caller to contract
        console.log(`\n🔄 Transferring tokens from caller to contract...`)
        const transferTx = await oft.transfer(oftAddress!, amountLD)
        const transferReceipt = await transferTx.wait()
        console.log(`  ✅ Transfer transaction confirmed: ${transferReceipt.transactionHash}`)
        console.log(`  📝 Transferred ${amount} tokens to contract`)
        
        // Verify contract now has the tokens
        const contractBalance = await oft.balanceOf(oftAddress!)
        console.log(`  🏦 Contract balance after transfer: ${ethers.utils.formatUnits(contractBalance, decimals)}`)

        // Convert message type string to enum value
        let messageTypeValue: number
        if (messageType === 'CROSS_CHAIN_SEND') {
            messageTypeValue = 0 // ComposeMsg.MessageType.CROSS_CHAIN_SEND
        } else if (messageType === 'BURNT') {
            messageTypeValue = 1 // ComposeMsg.MessageType.BURNT
        } else {
            throw new Error(`Invalid message type: ${messageType}. Must be CROSS_CHAIN_SEND or BURNT`)
        }

        console.log(`\n📝 Using message type: ${messageType} (${messageTypeValue})`)
        console.log(`  Extra options: ${extraOptions}`)
        console.log(`  Pay in LZ token: ${payInLzToken}`)

        // Quote the send operation
        console.log(`\n💰 Quoting send operation...`)
        const quote = await oft.quoteSendComposed(
            recipient,
            amountLD,
            dstEid,
            messageTypeValue,
            payInLzToken,
            extraOptions
        )
        const nativeFee = quote.nativeFee
        const lzTokenFee = quote.lzTokenFee

        console.log(`  Native fee: ${ethers.utils.formatEther(nativeFee)} ETH`)
        console.log(`  LZ token fee: ${lzTokenFee.toString()}`)

        // Check if user has enough ETH for gas (only if not paying in LZ tokens)
        if (!payInLzToken) {
            const ethBalance = await ethers.provider.getBalance(signer.address)
            if (ethers.BigNumber.from(ethBalance).lt(nativeFee)) {
                throw new Error(`Insufficient ETH for gas. Have: ${ethers.utils.formatEther(ethBalance)} ETH, Need: ${ethers.utils.formatEther(nativeFee)} ETH`)
            }
        }

        // Send the transaction
        console.log(`\n🚀 Sending composed message...`)
        const txValue = payInLzToken ? 0 : nativeFee
        const tx = await oft.connect(signer as any).sendComposed(
            recipient,
            amountLD,
            dstEid,
            messageTypeValue,
            payInLzToken,
            extraOptions,
            { value: txValue }
        )

        console.log(`📤 Transaction sent: ${tx.hash}`)
        console.log(`⏳ Waiting for confirmation...`)

        const receipt = await tx.wait()
        console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`)
        console.log(`   Gas used: ${receipt.gasUsed.toString()}`)

        // Generate LayerZero scan link
        const txHash = receipt.transactionHash
        const isTestnet = srcEid >= 40_000 && srcEid < 50_000
        const scanLink = getLayerZeroScanLink(txHash, isTestnet)
        
        console.log(`\n🔗 Transaction Links:`)
        console.log(`   Transaction Hash: ${txHash}`)
        console.log(`   LayerZero Scan: ${scanLink}`)
        console.log(`   📊 Track your cross-chain transaction: ${scanLink}`)

        // Parse events to show what happened
        try {
            const events = receipt.logs.map((log: any) => {
                try {
                    return oft.interface.parseLog(log)
                } catch {
                    return null
                }
            }).filter(Boolean)

            console.log(`\n📋 Events emitted:`)
            events.forEach((event: any, index: number) => {
                if (event) {
                    console.log(`  ${index + 1}. ${event.name}`)
                    if (event.name === 'OFTSent') {
                        console.log(`     - guid: ${event.args.guid}`)
                        console.log(`     - dstEid: ${event.args.dstEid}`)
                        console.log(`     - from: ${event.args.from}`)
                        console.log(`     - amountSentLD: ${ethers.utils.formatUnits(event.args.amountSentLD, decimals)}`)
                        console.log(`     - amountReceivedLD: ${ethers.utils.formatUnits(event.args.amountReceivedLD, decimals)}`)
                    } else if (event.name === 'CrossChainSendInitiated') {
                        console.log(`     - recipient: ${event.args.recipient}`)
                        console.log(`     - amount: ${ethers.utils.formatUnits(event.args.amount, decimals)}`)
                        console.log(`     - dstEid: ${event.args.dstEid}`)
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
                `Source Network: ${network.name}`,
                `Source EID: ${srcEid}`,
                `Destination EID: ${dstEid}`,
                `From: ${signer.address}`,
                `To: ${recipient}`,
                `Amount: ${amount}`,
                `Message Type: ${messageType}`,
                `Pay in LZ Token: ${payInLzToken}`,
                `Extra Options: ${extraOptions}`,
                `OFT Contract: ${oftAddress}`,
                `CrossChainManager: ${crossChainManagerAddress}`,
                `Transaction: ${txHash}`,
                `Gas Used: ${receipt.gasUsed.toString()}`,
                `Native Fee: ${ethers.utils.formatEther(nativeFee)} ETH`,
                `LayerZero Scan: ${scanLink}`,
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
