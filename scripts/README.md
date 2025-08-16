# Solana-EVM OFT Deployment Scripts

This directory contains comprehensive bash scripts for deploying and managing Solana-EVM Omnichain Fungible Token (OFT) projects.

## 📁 Scripts Overview

### 🚀 `deploy-steps.sh` - Complete Deployment Workflow
**Comprehensive deployment script with individual steps and full automation**

```bash
./scripts/deploy-steps.sh <COMMAND>
```

**Available Commands:**
```bash
build_program      # Step 1: Build the Solana OFT program
deploy_program     # Step 2: Deploy Solana OFT program and EVM AlphaOFT
create_oft_store   # Step 3: Create the Solana OFT store
init_solana_config # Step 4: Initialize Solana configuration
wire_connections   # Step 5: Wire cross-chain connections
setup_cross_chain_managers # Step 6: Setup cross-chain manager addresses for all networks
verify_deployment  # Step 7: Verify deployment files

# Token Management
mint_alpha_tokens_sepolia # Mint 100 billion Alpha tokens to treasury on Sepolia
transfer_tokens_treasury_to_owner # Transfer tokens from treasury to owner for cross-chain operations

# Testing Cross-Chain Transfers
test_cross_chain_message_to_solana # Test standard OFT: Sepolia -> Solana (amount=1)
test_cross_chain_message_from_sepolia_to_holesky # Test standard OFT: Sepolia -> Holesky (amount=1)
test_composed_message_from_sepolia_to_holesky # Test composed message: Sepolia -> Holesky (amount=1000)

# Utilities
debug_solana_deployment # Debug Solana OFT deployment and peer configurations
show_summary       # Show deployment summary
full_process       # Complete deployment workflow (all steps + logging)
help               # Show help message
```

**Features:**
- ✅ Individual step control for granular deployment
- ✅ Complete automated workflow with `full_process`
- ✅ Comprehensive logging to `deployment_full_process.log`
- ✅ Time tracking and performance monitoring
- ✅ AlphaTokenCrossChainManager deployment support
- ✅ Multi-network deployment verification
- ✅ Colored output and progress tracking

**Environment Variables:**
```bash
# Variables are automatically loaded from .env file
COMPUTE_UNIT_PRICE=1000        # Compute unit price for Solana deployment
INITIAL_AMOUNT=100000000000    # Initial OFT amount to mint
TOKEN_NAME=MyOFT               # Token name
TOKEN_SYMBOL=MOFT              # Token symbol
SOLANA_PRIVATE_KEY=your_key    # Solana private key (base58 encoded) for fee setting
```

**Example Usage:**
```bash
# Individual steps
./scripts/deploy-steps.sh build_program
./scripts/deploy-steps.sh deploy_program
./scripts/deploy-steps.sh create_oft_store
./scripts/deploy-steps.sh init_solana_config
./scripts/deploy-steps.sh wire_connections
./scripts/deploy-steps.sh check_and_set_fees
./scripts/deploy-steps.sh check_solana_fees
./scripts/deploy-steps.sh set_solana_fees

# Complete automated workflow (recommended)
./scripts/deploy-steps.sh full_process

# Verification and summary
./scripts/deploy-steps.sh verify_deployment
./scripts/deploy-steps.sh show_summary
```

---

### 🔧 `deploy-steps.sh` - Individual Deployment Steps
**Granular control over each deployment step**

```bash
./scripts/deploy-steps.sh <COMMAND>
```

**Available Commands:**
```bash
build_program      # Step 1: Build the Solana OFT program
deploy_program     # Step 2: Deploy the Solana OFT program
create_oft_store   # Step 3: Create the Solana OFT store
init_solana_config # Step 4: Initialize Solana configuration
wire_connections   # Step 5: Wire cross-chain connections
setup_cross_chain_managers # Step 6: Setup cross-chain manager addresses for all networks
check_and_set_fees # Step 7: Check and set chain transfer fees
check_solana_fees  # Step 7b: Check Solana to EVM chain transfer fees
set_solana_fees    # Step 7c: Set Solana to EVM chain transfer fees
verify_deployment  # Step 8: Verify deployment files
show_summary       # Step 9: Show deployment summary
full_process       # Complete deployment workflow (all steps + logging)
help               # Show help message
```

**Example Usage:**
```bash
# Build only
./scripts/deploy-steps.sh build_program

# Deploy program only
./scripts/deploy-steps.sh deploy_program

# Create OFT store only
./scripts/deploy-steps.sh create_oft_store

# Verify deployment
./scripts/deploy-steps.sh verify_deployment

# Complete workflow with logging
./scripts/deploy-steps.sh full_process
```

---


### ⚙️ `setup-env.sh` - Environment Setup and Validation
**Environment configuration and validation tools**

```bash
./scripts/setup-env.sh <COMMAND>
```

**Available Commands:**
```bash
check-prereqs      # Check if all prerequisites are installed
create-env         # Create .env file from template
validate-env       # Validate environment configuration
check-solana       # Check Solana balance and configuration
check-evm          # Check EVM balance and configuration
setup-all          # Run all setup checks
help               # Show help message
```

**Example Usage:**
```bash
# Check all prerequisites
./scripts/setup-env.sh check-prereqs

# Create environment file
./scripts/setup-env.sh create-env

# Validate configuration
./scripts/setup-env.sh validate-env

# Complete setup
./scripts/setup-env.sh setup-all
```

---

## 🛠️ Prerequisites

Before running the deployment scripts, ensure you have the following installed:

### Required Tools
- **Rust** `v1.75.0+`
- **Anchor** `v0.29.0`
- **Solana CLI** `v1.17.31` (for building) and `v1.18.26` (for deploying)
- **Node.js** `>=18.16.0`
- **pnpm** (recommended) or npm
- **Docker** `28.3.0+`

### Optional Tools
- **Foundry** `>=0.2.0` (for testing)

### Installation Commands
```bash
# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Anchor
cargo install --git https://github.com/coral-xyz/anchor --tag v0.29.0 anchor-cli --locked

# Solana
sh -c "$(curl -sSfL https://release.anza.xyz/v1.17.31/install)"

# Node.js
# Download from https://nodejs.org/

# pnpm
npm install -g pnpm

# Docker
# Download from https://docs.docker.com/get-docker/

# Foundry (optional)
curl -L https://foundry.paradigm.xyz | bash
```

---

## 🔧 Environment Configuration

### 1. Create Environment File
```bash
./scripts/setup-env.sh create-env
```

### 2. Configure Required Variables
Edit the `.env` file with your values:

```bash
# Solana Configuration
SOLANA_PRIVATE_KEY=your_solana_private_key_here
# OR use keypair file path:
# SOLANA_KEYPAIR_PATH=~/.config/solana/id.json

# Solana RPC URLs
RPC_URL_SOLANA_TESTNET=https://api.devnet.solana.com

# EVM Configuration
MNEMONIC=your_mnemonic_phrase_here
# OR use private key:
# PRIVATE_KEY=your_private_key_here

# EVM RPC URLs
RPC_URL_SEPOLIA=https://gateway.tenderly.co/public/sepolia

# Optional: Deployment Configuration
COMPUTE_UNIT_PRICE=1000
INITIAL_AMOUNT=100000000000
TOKEN_NAME=MyOFT
TOKEN_SYMBOL=MOFT
```

### 3. Validate Configuration
```bash
./scripts/setup-env.sh validate-env
```

---

## 🚀 Deployment Workflow

### Quick Start (Recommended)
```bash
# 1. Setup environment
./scripts/setup-env.sh setup-all

# 2. Complete deployment with logging
./scripts/deploy-steps.sh full_process
```

### Step-by-Step Deployment
```bash
# 1. Setup environment
./scripts/setup-env.sh setup-all

# 2. Build Solana program
./scripts/deploy-steps.sh build_program

# 3. Deploy Solana program
./scripts/deploy-steps.sh deploy_program

# 4. Create OFT store
./scripts/deploy-steps.sh create_oft_store

# 5. Initialize Solana configuration
./scripts/deploy-steps.sh init_solana_config

# 6. Wire cross-chain connections
./scripts/deploy-steps.sh wire_connections

# 7. Setup cross-chain managers
./scripts/deploy-steps.sh setup_cross_chain_managers

# 8. Verify deployment
./scripts/deploy-steps.sh verify_deployment

# 9. Show summary
./scripts/deploy-steps.sh show_summary
```

---

## 🔗 Cross-Chain Manager Configuration

The deployment process includes setting up cross-chain manager addresses for each network. This is handled automatically in the deployment workflow or can be run manually.

### Automatic Setup (Recommended)
Cross-chain managers are configured automatically during the full deployment process:

```bash
# Included in full process
./scripts/deploy-steps.sh full_process

# Or run individually after wire_connections
./scripts/deploy-steps.sh setup_cross_chain_managers
```

### Manual Setup
You can also configure cross-chain managers manually for specific networks:

```bash
# Setup managers for current network
pnpm hardhat --network sepolia-testnet lz:oft:set-cross-chain-managers

# Preview changes without executing
pnpm hardhat --network sepolia-testnet lz:oft:set-cross-chain-managers --dry-run true
```

### Features
- ✅ Reads cross-chain manager addresses from `deployments.json` automatically
- ✅ Maps network names to LayerZero endpoint IDs automatically
- ✅ Sets up cross-chain managers for all destination networks
- ✅ Comprehensive error handling and validation
- ✅ Progress tracking and colored output

### Networks Supported
- `sepolia-testnet` (EID: 40161)
- `holesky-testnet` (EID: 40217)
- `ethereum` (EID: 30101)
- `bsc` (EID: 30102)
- And more...

---

## 🔗 AlphaTokenCrossChainManager Deployment

The deployment process includes the AlphaTokenCrossChainManager contract, which handles cross-chain messaging functionality.

### Deployment Features
- **Automatic Deployment**: Deployed automatically during the `deploy_program` step
- **Multi-Network Support**: Deployed to all configured networks (Sepolia, BSC Testnet, Avalanche Fuji, Holesky)
- **Verification**: Automatically verified on block explorers after deployment
- **Configuration**: Uses parameters from `deployments.json` for each network

### Manual Deployment
```bash
# Deploy to specific network
pnpm hardhat deploy --network sepolia-testnet --tags AlphaTokenCrossChainManager

# Deploy to all networks
pnpm hardhat deploy --tags AlphaTokenCrossChainManager
```

### Verification
```bash
# Verify on specific network
pnpm hardhat verify --network sepolia-testnet <CONTRACT_ADDRESS> <TREASURY> <LZ_ENDPOINT> <TOKEN_ADDRESS>

# Check deployment status
./scripts/deploy-steps.sh verify_deployment
```

---

## 📊 Deployment Verification

### Check Deployment Status
```bash
./scripts/deploy-steps.sh verify_deployment
```

**Verification Features:**
- ✅ Solana OFT deployment verification
- ✅ AlphaTokenCrossChainManager deployments across all networks
- ✅ Contract address validation
- ✅ Multi-network status reporting

### View Deployment Summary
```bash
./scripts/deploy-steps.sh show_summary
```

**Summary Features:**
- ✅ LayerZero configuration display
- ✅ Solana deployment information
- ✅ AlphaTokenCrossChainManager deployment status for all networks
- ✅ Deployment count and statistics

### Manual Verification
```bash
# Check Solana deployment
ls -la deployments/solana-testnet/

# Check AlphaTokenCrossChainManager deployments
ls -la deployments/sepolia-testnet/AlphaTokenCrossChainManager.json
ls -la deployments/bsc-testnet/AlphaTokenCrossChainManager.json
ls -la deployments/avalanche-fuji/AlphaTokenCrossChainManager.json
ls -la deployments/holesky/AlphaTokenCrossChainManager.json

# View deployment details
cat deployments/solana-testnet/OFT.json
cat deployments/sepolia-testnet/AlphaTokenCrossChainManager.json
```

### Log File Analysis
```bash
# View complete deployment log
cat deployment_full_process.log

# Check deployment timing
grep "Start Time\|End Time\|Total Duration" deployment_full_process.log

# Check for errors
grep "❌\|ERROR\|FAILED" deployment_full_process.log
```

---

## 🧪 Testing

This repo includes scripts and tests to validate cross-chain message compatibility in both directions.

### One-click scripts

```bash
# EVM → Solana: generate message on EVM, verify Rust decoding
./scripts/test_evm_to_solana.sh

# Solana → EVM: generate message on Solana (Rust), verify EVM decoding
./scripts/test_solana_to_evm.sh
```

Both scripts will:
- Generate the corresponding message JSON into `test-results/`
- Print key fields for quick inspection
- Run the opposite side’s decoder test to verify compatibility

### Manual testing (advanced)

EVM → Solana
```bash
# 1) Generate EVM → Solana message JSON
pnpm hardhat test test/hardhat/MessageCompatibility.test.ts \
  --grep "should encode message to real Solana address and save to JSON"

# 2) Verify Rust can decode it
cargo test --manifest-path programs/oft/Cargo.toml \
  test_decode_real_evm_message -- --nocapture
```

Solana → EVM
```bash
# 1) Generate Solana → EVM message JSON via Rust
cargo test --manifest-path programs/oft/Cargo.toml \
  test_encode_solana_to_evm_message -- --nocapture

# 2) Verify EVM can decode it
pnpm hardhat test test/hardhat/SolanaToEvmCompatibility.test.ts
```

Generated files:
- `test-results/evm_to_solana_message.json` and `.hex`
- `test-results/solana_to_evm_message.json` and `.hex`

---

## 🔍 Troubleshooting

### Common Issues

#### 1. Solana Version Conflicts
```bash
# Check current version
solana --version

# Switch to required version
sh -c "$(curl -sSfL https://release.anza.xyz/v1.17.31/install)"
```

#### 2. Insufficient Balance
```bash
# Check Solana balance
./scripts/setup-env.sh check-solana

# Get devnet SOL
solana airdrop 5 -u devnet

# Check EVM balance
./scripts/setup-env.sh check-evm
```

#### 3. Environment Issues
```bash
# Validate environment
./scripts/setup-env.sh validate-env

# Check prerequisites
./scripts/setup-env.sh check-prereqs
```

#### 4. Build Errors
```bash
# Clean build artifacts
rm -rf target artifacts cache out .anchor

# Rebuild
./scripts/deploy-steps.sh build_program
```

#### 5. Deployment Failures
```bash
# Check logs
tail -f ~/.config/solana/id.json

# Retry with higher compute unit price
COMPUTE_UNIT_PRICE=2000 ./scripts/deploy-steps.sh deploy_program
```

#### 6. Address Lookup Table Errors
**Error:** `AccountNotFoundError: The account of type [AddressLookupTable] was not found at the provided address`

**Problem:** The address lookup table exists on devnet but not on testnet, causing deployment failures when using testnet endpoint.

**Solution:** Configure the RPC URL to point to devnet while keeping the testnet endpoint ID:

```bash
# Add to .env file
RPC_URL_SOLANA_TESTNET=https://api.devnet.solana.com
```

**Why this works:**
- LayerZero config uses testnet endpoint ID (40168) for proper network identification
- RPC URL points to devnet where the lookup table actually exists
- This allows the tools to fetch the lookup table while maintaining testnet configuration

**Verification:**
```bash
# Check if lookup table exists on devnet
solana address-lookup-table get 9thqPdbR27A1yLWw2spwJLySemiGMXxPnEvfmXVk4KuK --url devnet

# Check if lookup table exists on testnet (should fail)
solana address-lookup-table get 9thqPdbR27A1yLWw2spwJLySemiGMXxPnEvfmXVk4KuK --url testnet
```

**Alternative Solutions:**
1. **Use devnet endpoint**: Change LayerZero config to use `SOLANA_V2_SANDBOX` (50168)
2. **Remove lookup table**: Modify code to gracefully handle missing lookup tables
3. **Create new lookup table**: Deploy a new lookup table on testnet

---

## 📝 Script Features

### ✅ Error Handling
- Automatic error detection and reporting
- Graceful failure with helpful error messages
- Rollback capabilities for failed deployments

### ✅ Progress Tracking
- Colored output for different message types
- Step-by-step progress indicators
- Detailed logging of all operations

### ✅ Comprehensive Logging
- Single log file (`deployment_full_process.log`) for complete audit trail
- Start and end time tracking with duration calculation
- Step-by-step execution logging with timestamps
- Error capture and detailed failure reporting

### ✅ Environment Management
- Automatic Solana version switching
- Environment variable validation
- Prerequisite checking

### ✅ Flexibility
- Individual step control for granular deployment
- Complete automated workflow with `full_process`
- Customizable deployment parameters

### ✅ Multi-Network Support
- AlphaTokenCrossChainManager deployment across all configured networks
- Network-specific configuration from `deployments.json`
- Automatic verification on block explorers

### ✅ Verification & Monitoring
- Automatic deployment verification
- Multi-network deployment status checking
- Configuration validation
- Performance timing and monitoring

---

## 🔧 Available Hardhat Tasks

In addition to the automated scripts, several Hardhat tasks are available for manual operations:

### Token Management Tasks

```bash
# Mint AlphaOFT tokens to an address
pnpm hardhat --network sepolia-testnet lz:oft:mint --to <ADDRESS> --amount <AMOUNT>

# Check token balance for an address
pnpm hardhat --network sepolia-testnet lz:oft:balance --address <ADDRESS>

# Transfer tokens between addresses (requires owner privileges)
pnpm hardhat --network sepolia-testnet lz:oft:transfer --from <FROM_ADDRESS> --to <TO_ADDRESS> --amount <AMOUNT>
```

### Cross-Chain Messaging Tasks

```bash
# Standard OFT send
pnpm hardhat lz:oft:send --src-eid <SRC_EID> --dst-eid <DST_EID> --to <RECIPIENT> --amount <AMOUNT>

# Composed cross-chain message send
pnpm hardhat lz:oft:send-composed \
  --src-eid <SRC_EID> \
  --dst-eid <DST_EID> \
  --amount <AMOUNT> \
  --recipient <RECIPIENT> \
  --message-type <MESSAGE_TYPE> \
  [--pay-in-lz-token] \
  [--extra-options <HEX_OPTIONS>]
```

### Configuration Tasks

```bash
# Setup cross-chain managers for all networks
pnpm hardhat --network <NETWORK> lz:oft:set-cross-chain-managers

# Deploy AlphaTokenCrossChainManager
pnpm hardhat --network <NETWORK> deploy --tags AlphaTokenCrossChainManager

# Wire LayerZero connections
pnpm hardhat lz:oapp:wire --oapp-config layerzero.config.ts
```

### Example Usage

```bash
# Complete token setup workflow
pnpm hardhat --network sepolia-testnet lz:oft:mint --to 0x6E3a149F0972F9810B46D50C95e81A88b3f38E80 --amount 100000000000
pnpm hardhat --network sepolia-testnet lz:oft:balance --address 0x6E3a149F0972F9810B46D50C95e81A88b3f38E80
pnpm hardhat --network sepolia-testnet lz:oft:transfer --from 0x6E3a149F0972F9810B46D50C95e81A88b3f38E80 --to 0x323bfb6D2eD5D8Cc7F74e8c580E87dFA57719859 --amount 1000000000

# Send composed cross-chain message
pnpm hardhat lz:oft:send-composed --src-eid 40161 --dst-eid 40217 --amount 1000 --recipient "0x6E3a149F0972F9810B46D50C95e81A88b3f38E80" --message-type "CROSS_CHAIN_SEND"
```

## 🔗 Related Documentation

- [Main README](../README.md) - Project overview and manual deployment
- [LayerZero Documentation](https://docs.layerzero.network/) - Official LayerZero docs
- [Solana OFT Guide](https://docs.layerzero.network/v2/developers/solana/oft) - Solana OFT specific docs

---

## 🤝 Contributing

When adding new scripts or modifying existing ones:

1. Follow the existing code style and structure
2. Add proper error handling and validation
3. Include help documentation
4. Test thoroughly before committing
5. Update this README with any new features

---

## 📄 License

This project is licensed under the same terms as the main project. See the main README for details. 