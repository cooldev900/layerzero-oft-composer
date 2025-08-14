import fs from 'fs'
import path from 'path'
import dotenv from 'dotenv';
dotenv.config();

// Strong types for deployments.json
interface NetworkEntry {
  network: string
  chainId: string
  tokenAddress?: string
  treasury?: string
  lzEndpoint?: string
  mockLzEndpoint?: string | null
  deployer?: string
  isPrimary?: boolean
  totalSupply?: string
  status?: string
  deploymentTime?: string
  crossChainManager?: string
  transferRestrictions?: string
  securityManager?: string
  vestingIntegration?: string
  metadataManager?: string
}

interface DeploymentsFile {
  version: string
  lastUpdated: string
  networks: Record<string, NetworkEntry>
  metadata?: Record<string, unknown>
  chainIds: Record<string, Record<string, number>> // { testnet: { sepolia: 11155111 }, mainnet: {...} }
}

// Metadata.json structure: map of network key => NetworkData
interface AddressRef { address?: string }
interface BlockExplorer { url: string }
interface RpcEndpoint { url: string }
interface DvnInfo { version: number; canonicalName: string; id: string; deprecated?: boolean }
interface OAppInfo { id: string; canonicalName: string }

interface DeploymentEntry {
  eid?: string | number
  version?: number
  chainKey?: string
  stage?: string
  endpoint?: AddressRef
  endpointV2?: AddressRef
  endpointV2View?: AddressRef
  relayerV2?: AddressRef
  ultraLightNodeV2?: AddressRef
  sendUln301?: AddressRef
  receiveUln301?: AddressRef
  sendUln302?: AddressRef
  receiveUln302?: AddressRef
  lzExecutor?: AddressRef
  blockedMessageLib?: AddressRef
  nonceContract?: AddressRef
  [k: string]: unknown
}

interface ChainDetails {
  chainKey?: string
  chainStatus?: string
  nativeChainId?: number
  chainLayer?: string
  nativeCurrency?: { symbol?: string; cgId?: string; cmcId?: number; decimals?: number }
  chainType?: string
  averageBlockTime?: number
  [k: string]: unknown
}

interface TokenPegInfo { symbol?: string; chainName?: string; address?: string; programaticallyPegged?: boolean }
interface TokenInfo {
  symbol?: string
  name?: string
  decimals?: number
  stablecoin?: boolean
  canonicalAsset?: boolean
  erc20TokenAddress?: string
  endpointVersion?: number
  oftVersion?: number
  type?: string
  sharedDecimals?: number
  mintAndBurn?: boolean
  peggedTo?: TokenPegInfo
  proxyAddresses?: string[]
  [k: string]: unknown
}

interface NetworkData {
  created?: string
  updated?: string
  tableName?: string
  environment?: string
  chainKey?: string
  chainName?: string
  blockExplorers?: BlockExplorer[]
  deployments?: DeploymentEntry[]
  chainDetails?: ChainDetails
  dvns?: Record<string, DvnInfo>
  rpcs?: RpcEndpoint[]
  addressToOApp?: Record<string, OAppInfo>
  tokens?: Record<string, TokenInfo>
  [k: string]: unknown
}

type MetadataRoot = Record<string, NetworkData>

function readJson<T>(filePath: string): T {
  const raw = fs.readFileSync(filePath, 'utf8')
  return JSON.parse(raw) as T
}

function writeJson(filePath: string, data: unknown) {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2))
}

// Find the endpointV2 address by matching chainIds against chainDetails.nativeChainId
function findEndpointForChainId(root: MetadataRoot, targetChainId: number): string | undefined {
  for (const data of Object.values(root)) {
    const nativeId = data.chainDetails?.nativeChainId
    if (typeof nativeId === 'number' && nativeId === targetChainId) {
      const deployments = Array.isArray(data.deployments) ? data.deployments : []
      // Prefer endpointV2
      for (const d of deployments) {
        const v2 = d.endpointV2?.address
        if (typeof v2 === 'string' && v2.length > 0) return v2
      }
    }
  }
  return undefined
}

// Main: sequentially read, update, write
;(function main() {
  const root = path.join(__dirname, '..')
  const deploymentsPath = path.join(root, 'deployments.json')
  const metadataPath = path.join(root, 'metadata.json')
  const historyLogPath = path.join(root, 'deployments-history.log')

  const ZERO_ADDR = '0x0000000000000000000000000000000000000000'

  const treasury = process.env.TREASURY_ADDRESS
  if (!treasury) {
    console.error('TREASURY_ADDRESS not set in environment variables')
    process.exit(1)
  }

  // session logger (sequential, file appended at the end)
  const sessionLogs: string[] = []
  const addLog = (msg: string) => {
    const line = `[${new Date().toISOString()}] ${msg}`
    sessionLogs.push(line)
    console.log(msg)
  }

  if (!fs.existsSync(deploymentsPath)) {
    console.error('deployments.json not found at', deploymentsPath)
    process.exit(1)
  }
  if (!fs.existsSync(metadataPath)) {
    console.error('metadata.json not found at', metadataPath, '- run pre_deployment first')
    process.exit(1)
  }

  const deployments = readJson<DeploymentsFile>(deploymentsPath)
  const metadata = readJson<MetadataRoot>(metadataPath)

  const now = new Date().toISOString()
  let changed = 0
  let processed = 0
  let createdCount = 0
  let endpointSets = 0
  let chainIdUpdatedCount = 0
  let defaultsSetCount = 0

  // Iterate chainIds sequentially (no Promise.all, no patching logic)
  const groups = deployments.chainIds || {}
  addLog(`Started update-networks-from-metadata`)
  for (const groupName of Object.keys(groups)) {
    const group = groups[groupName]
    for (const networkName of Object.keys(group)) {
      const chainId = group[networkName]
      processed++
      addLog(`Processing network '${networkName}' (chainId=${chainId})`)
      const endpoint = findEndpointForChainId(metadata, chainId)

      // Ensure network entry exists
      const wasExisting = Boolean(deployments.networks[networkName])
      const existing: NetworkEntry = deployments.networks[networkName] || {
        network: networkName,
        chainId: String(chainId),
        crossChainManager: ZERO_ADDR,
        transferRestrictions: ZERO_ADDR,
        securityManager: ZERO_ADDR,
        vestingIntegration: ZERO_ADDR,
        metadataManager: ZERO_ADDR,
        deployer: ZERO_ADDR,
        treasury,
      }
      if (!wasExisting) {
        createdCount++
        changed++
        addLog(`Created network entry '${networkName}' with defaults`)
      }

      // Always make sure chainId string matches
      if (existing.chainId !== String(chainId)) {
        existing.chainId = String(chainId)
        changed++
        chainIdUpdatedCount++
        addLog(`Updated chainId for '${networkName}' => ${chainId}`)
      }

      // Ensure required fields default to ZERO_ADDR if missing/empty
      if (!existing.crossChainManager) { existing.crossChainManager = ZERO_ADDR; changed++; defaultsSetCount++; addLog(`Defaulted crossChainManager => ${ZERO_ADDR}`) }
      if (!existing.transferRestrictions) { existing.transferRestrictions = ZERO_ADDR; changed++; defaultsSetCount++; addLog(`Defaulted transferRestrictions => ${ZERO_ADDR}`) }
      if (!existing.securityManager) { existing.securityManager = ZERO_ADDR; changed++; defaultsSetCount++; addLog(`Defaulted securityManager => ${ZERO_ADDR}`) }
      if (!existing.vestingIntegration) { existing.vestingIntegration = ZERO_ADDR; changed++; defaultsSetCount++; addLog(`Defaulted vestingIntegration => ${ZERO_ADDR}`) }
      if (!existing.metadataManager) { existing.metadataManager = ZERO_ADDR; changed++; defaultsSetCount++; addLog(`Defaulted metadataManager => ${ZERO_ADDR}`) }
      if (!existing.deployer) { existing.deployer = ZERO_ADDR; changed++; defaultsSetCount++; addLog(`Defaulted deployer => ${ZERO_ADDR}`) }
      if (!existing.treasury) { existing.treasury = ZERO_ADDR; changed++; defaultsSetCount++; addLog(`Defaulted treasury => ${ZERO_ADDR}`) }

      // Set endpoint if changed or missing
      if (endpoint && existing.lzEndpoint !== endpoint) {
        existing.lzEndpoint = endpoint
        changed++
        endpointSets++
        console.log(`Set lzEndpoint for '${networkName}' (chainId=${chainId}) => ${endpoint}`)
        addLog(`Set lzEndpoint for '${networkName}' => ${endpoint}`)
      }

      deployments.networks[networkName] = existing
    }
  }

  if (changed > 0) {
    deployments.lastUpdated = now
    writeJson(deploymentsPath, deployments)
    const summary = `Updated deployments.json: processed=${processed}, created=${createdCount}, endpointsSet=${endpointSets}, chainIdUpdates=${chainIdUpdatedCount}, defaultsSet=${defaultsSetCount}, totalChanges=${changed}`
    addLog(summary)
    try {
      const header = `\n===== update-networks-from-metadata @ ${now} =====\n`
      const snapshot = JSON.stringify(deployments, null, 2)
      const body = sessionLogs.join('\n') + `\n--- deployments.json (after update) ---\n` + snapshot + '\n'
      fs.appendFileSync(historyLogPath, header + body)
    } catch (e) {
      console.error('Failed to write deployments-history.log', e)
    }
    console.log(`\n✓ ${summary}`)
  } else {
    addLog('No changes; deployments.json already up-to-date')
    try {
      const header = `\n===== update-networks-from-metadata @ ${now} =====\n`
      const snapshot = JSON.stringify(deployments, null, 2)
      const body = sessionLogs.join('\n') + `\n--- deployments.json (after update) ---\n` + snapshot + '\n'
      fs.appendFileSync(historyLogPath, header + body)
    } catch (e) {
      console.error('Failed to write deployments-history.log', e)
    }
  }
})()