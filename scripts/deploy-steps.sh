#!/bin/bash

# Individual Deployment Steps Script for Solana-EVM OFT
# This script provides individual functions for each deployment step
# Use this for more granular control over the deployment process

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check environment
check_env() {
    if [ ! -f ".env" ]; then
        print_error ".env file not found. Please copy .env.example to .env and configure it."
        exit 1
    fi
    source .env
}

# Load .env file if it exists (for environment variables)
if [ -f ".env" ]; then
    print_status "Loading environment variables from .env file"
    # Load .env file, filtering out comments and empty lines, and handling spaces in values
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ $line =~ ^[[:space:]]*# ]] && continue
        [[ -z $line ]] && continue
        
        # Export the variable if it's a valid assignment
        if [[ $line =~ ^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*= ]]; then
            export "$line"
        fi
    done < .env
    
    # Show which Solana key variables are loaded (without exposing the actual values)
    if [ -n "$SOLANA_PRIVATE_KEY" ]; then
        print_status "✅ SOLANA_PRIVATE_KEY is loaded (${#SOLANA_PRIVATE_KEY} characters)"
    fi
fi

# Function to get Solana version
get_solana_version() {
    solana --version | cut -d' ' -f2
}

# Function to switch Solana version
switch_solana_version() {
    local target_version=$1
    local current_version=$(get_solana_version)
    
    if [ "$current_version" != "$target_version" ]; then
        print_status "Switching Solana from $current_version to $target_version..."
        
        case $target_version in
            "1.17.31")
                sh -c "$(curl -sSfL https://release.anza.xyz/v1.17.31/install)"
                ;;
            "1.18.26")
                sh -c "$(curl -sSfL https://release.anza.xyz/v1.18.26/install)"
                ;;
            *)
                print_error "Unsupported Solana version: $target_version"
                exit 1
                ;;
        esac
        
        print_success "Switched to Solana $target_version"
    else
        print_status "Already using Solana $target_version"
    fi
}

# Pre-deployment: fetch LayerZero metadata to metadata.json
pre_deployment() {
    print_status "Pre-deployment: Fetching LayerZero metadata"
    if ! command_exists curl; then
        print_error "curl is not installed. Please install curl and try again."
        exit 1
    fi

    local OUTPUT_FILE="metadata.json"
    # Choose environment (default to testnet). Allowed: mainnet | testnet | sandbox
    local LZ_ENVIRONMENT=${LZ_ENVIRONMENT:-testnet}
    print_status "Fetching LayerZero metadata for environment: $LZ_ENVIRONMENT"
    if curl -sSf "https://metadata.layerzero-api.com/v1/metadata?environment=$LZ_ENVIRONMENT" -o "$OUTPUT_FILE"; then
        local BYTES=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')
        print_success "Saved LayerZero metadata to $OUTPUT_FILE (${BYTES} bytes)"
    else
        print_error "Failed to fetch LayerZero metadata"
        exit 1
    fi

    print_status "Updating deployments.json networks from metadata and chainIds"
    if command_exists pnpm; then
        pnpm ts-node scripts/update-networks-from-metadata.ts || {
            print_error "Failed to update deployments.json from metadata"
            exit 1
        }
    else
        npx ts-node scripts/update-networks-from-metadata.ts || {
            print_error "Failed to update deployments.json from metadata"
            exit 1
        }
    fi
    print_success "Solidity contracts built successfully"
}

# Step 1: Build Solana OFT Program
build_program() {
    print_status "Step 1: Building Solana OFT Program"
    echo "=========================================="
    
    check_env
    
    # Check requirements
    if ! command_exists anchor; then
        print_error "Anchor CLI not found. Please install Anchor v0.29.0"
        exit 1
    fi
    
    if ! command_exists solana; then
        print_error "Solana CLI not found. Please install Solana"
        exit 1
    fi
    
    # Switch to Solana 1.17.31 for building
    switch_solana_version "1.17.31"
    
    # Generate program keypair if it doesn't exist
    if [ ! -f "target/deploy/oft-keypair.json" ]; then
        print_status "Generating OFT program keypair..."
        anchor keys sync -p oft
    fi
    
    # Get the program ID
    local program_id=$(anchor keys list | grep "oft:" | awk '{print $2}')
    
    if [ -z "$program_id" ]; then
        print_error "Failed to get OFT program ID"
        exit 1
    fi
    
    print_status "OFT Program ID: $program_id"
    
    # Build the program
    anchor build -v -e OFT_ID="$program_id"
    
    # Save program ID for later use
    echo "$program_id" > .program_id
    
    print_success "Solana OFT program built successfully"
    print_status "Program ID saved to .program_id"
}

# Step 2: Deploy Solana OFT Program
deploy_solana_program() {
    print_status "Step 2a: Deploying Solana OFT Program"
    echo "========================================"
    
    check_env
    
    if [ ! -f ".program_id" ]; then
        print_error "Program ID not found. Please run build_program first."
        exit 1
    fi
    
    # Switch to Solana 1.17.31 for deployment
    switch_solana_version "1.17.31"
    
    local program_id=$(cat .program_id)
    local compute_unit_price=${COMPUTE_UNIT_PRICE:-1000}
    
    print_status "Deploying with compute unit price: $compute_unit_price micro-lamports"
    print_status "Program ID: $program_id"
    
    # Deploy the program
    print_status "Deploying Solana OFT program..."
    solana program deploy \
        --program-id target/deploy/oft-keypair.json \
        target/verifiable/oft.so \
        -u devnet
    
    print_success "Solana OFT program deployed successfully"
    
    # Switch back to Solana 1.17.31 for future builds
    switch_solana_version "1.17.31"
}

deploy_evm_contracts() {
    print_status "Step 2b: Deploying EVM Contracts"
    echo "================================="
    
    check_env

    pnpm hardhat lz:deploy --tags AlphaOFT
    print_success "AlphaOFT deployed (see deployments/AlphaOFT.json)"
}

deploy_program() {
    print_status "Step 2: Deploying Both Solana and EVM"
    echo "======================================"
    deploy_solana_program
    deploy_evm_contracts
}

# Step 3: Create Solana OFT Store
create_oft_store() {
    print_status "Step 3: Creating Solana OFT Store"
    echo "======================================="
    
    check_env
    
    if [ ! -f ".program_id" ]; then
        print_error "Program ID not found. Please run build_program first."
        exit 1
    fi
    
    if ! command_exists pnpm; then
        print_error "pnpm not found. Please install pnpm"
        exit 1
    fi
    
    local program_id=$(cat .program_id)
    local initial_amount=${INITIAL_AMOUNT:-0}
    
    # Read token name and symbol from deployments.json if available, otherwise use defaults
    local token_name
    local token_symbol
    
    if [ -f "deployments.json" ] && command_exists jq; then
        token_name=${TOKEN_NAME:-$(jq -r '.metadata.tokenName // "MyOFT"' deployments.json)}
        token_symbol=${TOKEN_SYMBOL:-$(jq -r '.metadata.tokenSymbol // "MOFT"' deployments.json)}        
    else
        token_name=${TOKEN_NAME:-"MyOFT"}
        token_symbol=${TOKEN_SYMBOL:-"MOFT"}
        token_uri=${TOKEN_URI:-""}
    fi
    
    print_status "Creating OFT with:"
    print_status "  - Program ID: $program_id"
    print_status "  - Initial Amount: $initial_amount"
    print_status "  - Token Name: $token_name"
    print_status "  - Token Symbol: $token_symbol"
    
    # Create the OFT
    # 50168 is the solana devnet chain id
    # local-decimals is 8 since max supply is 100000000000
    pnpm hardhat lz:oft:solana:create \
        --eid 40168 \
        --program-id "$program_id" \
        --only-oft-store true \
        --amount "$initial_amount" \
        --name "$token_name" \
        --symbol "$token_symbol" \
        --local-decimals 8
    
    print_success "Solana OFT store created successfully"
}

# Step 4: Initialize Solana Configuration
init_solana_config() {
    print_status "Step 4: Initializing Solana Configuration"
    echo "================================================"
    
    check_env
    
    if ! command_exists pnpm; then
        print_error "pnpm not found. Please install pnpm"
        exit 1
    fi
    
    print_status "Initializing Solana configuration..."
    
    pnpm hardhat lz:oft:solana:init-config --oapp-config layerzero.config.ts
    
    print_success "Solana configuration initialized successfully"
}

# Step 5: Wire Cross-Chain Connections
wire_connections() {
    print_status "Step 5: Wiring Cross-Chain Connections"
    echo "============================================="
    
    check_env
    
    if ! command_exists pnpm; then
        print_error "pnpm not found. Please install pnpm"
        exit 1
    fi
    
    print_status "Wiring cross-chain connections..."
    
    pnpm hardhat lz:oapp:wire --oapp-config layerzero.config.ts
    
    print_success "Cross-chain connections wired successfully"
}

# Step 7: Verify Deployment
verify_deployment() {
    print_status "Step 7: Verifying Deployment"
    echo "=================================="
    
    print_status "Checking deployment files..."
    
    # Check Solana deployment
    if [ -f "deployments/solana-testnet/OFT.json" ]; then
        local oft_store=$(jq -r '.oftStore' deployments/solana-testnet/OFT.json 2>/dev/null || echo "Not found")
        print_success "Solana OFT deployment found: $oft_store"
    else
        print_error "Solana OFT deployment not found"
        return 1
    fi
    
    # Check AlphaOFT deployment on known EVM network(s)
    print_status "Checking AlphaOFT EVM deployment(s)..."
    local networks=("sepolia-testnet")
    local any_found=false
    for network in "${networks[@]}"; do
        if [ -f "deployments/$network/AlphaOFT.json" ]; then
            local contract_address=$(jq -r '.address' "deployments/$network/AlphaOFT.json" 2>/dev/null || echo "Not found")
            print_success "$network AlphaOFT: $contract_address"
            any_found=true
        else
            print_warning "$network: AlphaOFT not deployed"
        fi
    done
    if [ "$any_found" != true ]; then
        print_warning "No AlphaOFT deployments found"
    fi
    
    print_success "Deployment verification completed"
}



# Step 8: Test Cross-Chain Message from EVM to Solana
test_cross_chain_message_to_solana() {
    print_status "Step 8: Testing Cross-Chain Message from EVM to Solana"
    echo "============================================================="
    
    check_env
    
    if ! command_exists pnpm; then
        print_error "pnpm not found. Please install pnpm"
        exit 1
    fi
    
    print_status "Testing cross-chain message from EVM (Sepolia) to Solana..."
    print_status "Source EID: 40161 (Sepolia)"
    print_status "Destination EID: 40168 (Solana)"
    print_status "Amount: 1000 tokens"
    print_status "Recipient: 64wFif4yGgYdLLeck3n4Vr1vJiAaKXrQHCBCHqWSBk1J"
    
    # Test cross-chain message from EVM to Solana
    pnpm hardhat lz:oft:send \
        --src-eid 40161 \
        --dst-eid 40168 \
        --amount 1 \
        --to 64wFif4yGgYdLLeck3n4Vr1vJiAaKXrQHCBCHqWSBk1J
    
    print_success "Cross-chain message test completed successfully"
}

# Send cross-chain message from EVM Sepolia to EVM Holesky
test_cross_chain_message_from_sepolia_to_holesky() {
    print_status "Step 8b: Testing Cross-Chain Message from Sepolia to Holesky"
    echo "============================================================="

    check_env

    if ! command_exists pnpm; then
        print_error "pnpm not found. Please install pnpm"
        exit 1
    fi

    print_status "Sending cross-chain message from EVM (Sepolia) to EVM (Holesky)..."
    print_status "Source EID: 40161 (Sepolia)"
    print_status "Destination EID: 40217 (Holesky)"
    print_status "Amount: 1000 tokens"
    print_status "Recipient: 0x6E3a149F0972F9810B46D50C95e81A88b3f38E80"

    pnpm hardhat lz:oft:send \
        --src-eid 40161 \
        --dst-eid 40217 \
        --amount 1 \
        --to "0x6E3a149F0972F9810B46D50C95e81A88b3f38E80"

    print_success "Cross-chain message Sepolia -> Holesky completed successfully"
}

# Step 9: Debug Solana OFT Deployment
debug_solana_deployment() {
    print_status "Step 9: Debugging Solana OFT Deployment"
    echo "=============================================="
    
    check_env
    
    if ! command_exists pnpm; then
        print_error "pnpm not found. Please install pnpm"
        exit 1
    fi
    
    # Check if OFT deployment exists
    if [ ! -f "deployments/solana-testnet/OFT.json" ]; then
        print_error "Solana OFT deployment not found. Please run create_oft_store first."
        exit 1
    fi
    
    # Get OFT store address from deployment
    local oft_store=$(jq -r '.oftStore' deployments/solana-testnet/OFT.json 2>/dev/null || echo "")
    
    if [ -z "$oft_store" ] || [ "$oft_store" = "null" ]; then
        print_error "Failed to get OFT store address from deployment file"
        exit 1
    fi
    
    print_status "Debugging Solana OFT deployment..."
    print_status "EID: 40168 (Solana Testnet)"
    print_status "OFT Store: $oft_store"
    
    # Define destination EIDs for peer configurations (EVM testnets)
    local dst_eids="40161,40102,40106,40217"  # Sepolia, BSC, Avalanche, Holesky
    
    print_status "Checking peer configurations for: $dst_eids"
    
    # Run the debug task
    pnpm hardhat lz:oft:solana:debug \
        --eid 40168 \
        --oft-store "$oft_store" \
        --dst-eids "$dst_eids"
    
    print_success "Solana OFT deployment debug completed"
}

# Step 10: Show Deployment Summary
show_summary() {
    print_status "Configuration Summary"
    npx hardhat lz:oapp:config:get --oapp-config layerzero.config.ts
    echo "==================="
    print_status "Deployment Summary"
    echo "==================="
    
    # Solana deployments
    if [ -f ".program_id" ]; then
        local program_id=$(cat .program_id)
        echo "Solana OFT Program ID: $program_id"
    fi
    
    if [ -f "deployments/solana-testnet/OFT.json" ]; then
        local oft_store=$(jq -r '.oftStore' deployments/solana-testnet/OFT.json 2>/dev/null || echo "Not found")
        echo "Solana OFT Store: $oft_store"
    fi
    
    # AlphaOFT deployments
    echo ""
    echo "AlphaOFT Deployments:"
    echo "----------------------"
    local networks=("sepolia-testnet")
    for network in "${networks[@]}"; do
        if [ -f "deployments/$network/AlphaOFT.json" ]; then
            local contract_address=$(jq -r '.address' "deployments/$network/AlphaOFT.json" 2>/dev/null || echo "Not found")
            echo "$network: $contract_address"
        else
            echo "$network: Not deployed"
        fi
    done
    echo ""
    echo "Summary:"
    echo "  - Solana OFT: $(if [ -f "deployments/solana-testnet/OFT.json" ]; then echo "Deployed"; else echo "Not deployed"; fi)"
    echo "  - AlphaOFT: $(if [ -f "deployments/sepolia-testnet/AlphaOFT.json" ]; then echo "Deployed"; else echo "Not deployed"; fi)"
    
    echo ""
    print_success "Deployment information displayed"
}

# Full Process: Complete deployment workflow
full_process() {
    # Create single log file
    local log_file="deployment_full_process.log"
    
    # Record start time
    local start_time=$(date)
    local start_timestamp=$(date +%s)
    
    print_status "Full Process: Complete Deployment Workflow"
    echo "================================================="
    
    print_status "Logging all output to: $log_file"
    
    # Clear previous log and start new one
    echo "=================================================" > "$log_file"
    echo "FULL DEPLOYMENT PROCESS LOG" >> "$log_file"
    echo "=================================================" >> "$log_file"
    echo "Start Time: $start_time" >> "$log_file"
    echo "=================================================" >> "$log_file"
    
    # Function to log and execute commands
    execute_step() {
        local step_name="$1"
        local step_function="$2"
        
        echo "" | tee -a "$log_file"
        echo "=== Starting $step_name ===" | tee -a "$log_file"
        echo "Time: $(date)" | tee -a "$log_file"
        echo "=================================================" | tee -a "$log_file"
        
        # Execute the step and capture output
        if $step_function 2>&1 | tee -a "$log_file"; then
            echo "" | tee -a "$log_file"
            echo "✅ $step_name completed successfully" | tee -a "$log_file"
            echo "=================================================" | tee -a "$log_file"
        else
            echo "" | tee -a "$log_file"
            echo "❌ $step_name failed" | tee -a "$log_file"
            echo "Check the log file for details: $log_file" | tee -a "$log_file"
            echo "=================================================" | tee -a "$log_file"
            exit 1
        fi
    }
    
    # Execute all steps in sequence
    execute_step "Build Solidity" build_solidity
    execute_step "Build Program" build_program
    execute_step "Deploy Program" deploy_program
    execute_step "Create OFT Store" create_oft_store
    execute_step "Initialize Solana Config" init_solana_config
    execute_step "Wire Connections" wire_connections
    execute_step "Verify Deployment" verify_deployment
    execute_step "Show Summary" show_summary
    
    # Record end time and calculate duration
    local end_time=$(date)
    local end_timestamp=$(date +%s)
    local duration=$((end_timestamp - start_timestamp))
    local duration_formatted=$(printf '%02d:%02d:%02d' $((duration/3600)) $((duration%3600/60)) $((duration%60)))
    
    echo "" | tee -a "$log_file"
    echo "=================================================" | tee -a "$log_file"
    echo "🎉 Full deployment process completed successfully!" | tee -a "$log_file"
    echo "=================================================" | tee -a "$log_file"
    echo "Start Time: $start_time" | tee -a "$log_file"
    echo "End Time: $end_time" | tee -a "$log_file"
    echo "Total Duration: $duration_formatted (${duration} seconds)" | tee -a "$log_file"
    echo "📋 Complete log saved to: $log_file" | tee -a "$log_file"
    echo "=================================================" | tee -a "$log_file"
}

# Function to show help
show_help() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  pre_deployment     Fetch LayerZero metadata (metadata.json)"
    echo "  build_program      Build the Solana OFT program"
    echo "  deploy_program     Deploy both Solana OFT program and EVM contracts"
    echo "  deploy_solana      Deploy only Solana OFT program"
    echo "  deploy_evm         Deploy only EVM contracts"
    echo "  create_oft_store   Create the Solana OFT store"
    echo "  init_solana_config Initialize Solana configuration"
    echo "  wire_connections   Wire cross-chain connections"
    echo "  check_and_set_fees Check and set chain transfer fees"
    echo "  verify_deployment  Verify deployment files"
    echo "  debug_solana_deployment Debug Solana OFT deployment and peer configurations"
    echo "  test_cross_chain_message Test cross-chain message from EVM to Solana"
    echo "  crosss_chain_message_from_sepolia_to_holesky Test cross-chain message from Sepolia to Holesky"
    echo "  show_summary       Show deployment summary"
    echo "  full_process       Complete deployment workflow (all steps)"
    echo "  help              Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  Variables are automatically loaded from .env file"
    echo "  COMPUTE_UNIT_PRICE  Compute unit price for Solana deployment (default: 1000)"
    echo "  INITIAL_AMOUNT      Initial OFT amount to mint (default: 100000000000)"
    echo "  TOKEN_NAME          Token name (default: MyOFT)"
    echo "  TOKEN_SYMBOL        Token symbol (default: MOFT)"
    echo "  TOKEN_URI           Token metadata URI (default: from deployments.json or empty)"
    echo "  SOLANA_PRIVATE_KEY  Solana private key (base58 encoded) for fee setting"
    echo ""
    echo "Examples:"
    echo "  $0 build_program"
    echo "  $0 deploy_program"
    echo "  $0 create_oft_store"
    echo "  $0 check_and_set_fees"
    echo "  $0 verify_deployment"
    echo "  $0 debug_solana_deployment"
    echo "  $0 test_cross_chain_message_to_solana"
    echo "  $0 test_cross_chain_message_from_sepolia_to_holesky"
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    case $1 in
        "build_program")
            build_program
            ;;
        "pre_deployment")
            pre_deployment
            ;;
        "deploy_program")
            deploy_program
            ;;
        "deploy_solana")
            deploy_solana_program
            ;;
        "deploy_evm")
            deploy_evm_contracts
            ;;
        "create_oft_store")
            create_oft_store
            ;;
        "init_solana_config")
            init_solana_config
            ;;
        "wire_connections")
            wire_connections
            ;;
        "check_and_set_fees")
            check_and_set_fees
            ;;
        "verify_deployment")
            verify_deployment
            ;;
        "debug_solana_deployment")
            debug_solana_deployment
            ;;
        "test_cross_chain_message_to_solana")
            test_cross_chain_message_to_solana
            ;;
        "test_cross_chain_message_from_sepolia_to_holesky")
            test_cross_chain_message_from_sepolia_to_holesky
            ;;
        "show_summary")
            show_summary
            ;;
        "full_process")
            full_process
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 