#!/bin/bash

# Environment Setup Script for Solana-EVM OFT
# This script helps configure the environment for deployment

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

# Function to get command version
get_version() {
    local cmd=$1
    local version_cmd=$2
    
    if command_exists "$cmd"; then
        eval "$version_cmd" 2>/dev/null | head -n1 || echo "Unknown version"
    else
        echo "Not installed"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking Prerequisites"
    echo "========================"
    
    local missing_tools=()
    local warnings=()
    
    # Check Rust
    if command_exists rustc; then
        local rust_version=$(get_version "rustc" "rustc --version")
        print_success "Rust: $rust_version"
    else
        missing_tools+=("Rust")
    fi
    
    # Check Anchor
    if command_exists anchor; then
        local anchor_version=$(get_version "anchor" "anchor --version")
        if [[ "$anchor_version" == *"0.29"* ]]; then
            print_success "Anchor: $anchor_version"
        else
            warnings+=("Anchor version should be 0.29.0, found: $anchor_version")
        fi
    else
        missing_tools+=("Anchor")
    fi
    
    # Check Solana
    if command_exists solana; then
        local solana_version=$(get_version "solana" "solana --version")
        print_success "Solana: $solana_version"
    else
        missing_tools+=("Solana")
    fi
    
    # Check Node.js
    if command_exists node; then
        local node_version=$(get_version "node" "node --version")
        print_success "Node.js: $node_version"
    else
        missing_tools+=("Node.js")
    fi
    
    # Check pnpm
    if command_exists pnpm; then
        local pnpm_version=$(get_version "pnpm" "pnpm --version")
        print_success "pnpm: $pnpm_version"
    else
        missing_tools+=("pnpm")
    fi
    
    # Check Docker
    if command_exists docker; then
        local docker_version=$(get_version "docker" "docker --version")
        print_success "Docker: $docker_version"
    else
        missing_tools+=("Docker")
    fi
    
    # Check Foundry (optional)
    if command_exists forge; then
        local forge_version=$(get_version "forge" "forge --version")
        print_success "Foundry: $forge_version"
    else
        print_warning "Foundry not installed (optional for testing)"
    fi
    
    echo ""
    
    # Report missing tools
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        print_status "Installation instructions:"
        echo "  Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        echo "  Anchor: cargo install --git https://github.com/coral-xyz/anchor --tag v0.29.0 anchor-cli --locked"
        echo "  Solana: sh -c \"\$(curl -sSfL https://release.anza.xyz/v1.17.31/install)\""
        echo "  Node.js: https://nodejs.org/"
        echo "  pnpm: npm install -g pnpm"
        echo "  Docker: https://docs.docker.com/get-docker/"
        echo "  Foundry: curl -L https://foundry.paradigm.xyz | bash"
        return 1
    fi
    
    # Report warnings
    if [ ${#warnings[@]} -ne 0 ]; then
        for warning in "${warnings[@]}"; do
            print_warning "$warning"
        done
    fi
    
    print_success "All prerequisites are satisfied"
    return 0
}

# Function to create .env file
create_env_file() {
    print_status "Setting up Environment File"
    echo "==============================="
    
    if [ -f ".env" ]; then
        print_warning ".env file already exists"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Keeping existing .env file"
            return 0
        fi
    fi
    
    # Copy from example if it exists
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_success "Created .env from .env.example"
    else
        # Create basic .env template
        cat > .env << 'EOF'
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
EOF
        print_success "Created basic .env template"
    fi
    
    print_warning "Please edit .env file with your actual values before deployment"
}

# Function to validate environment
validate_environment() {
    print_status "Validating Environment Configuration"
    echo "=========================================="
    
    if [ ! -f ".env" ]; then
        print_error ".env file not found"
        return 1
    fi
    
    # Source the .env file
    source .env
    
    local missing_vars=()
    local warnings=()
    
    # Check Solana configuration
    if [ -z "$SOLANA_PRIVATE_KEY" ] && [ -z "$SOLANA_KEYPAIR_PATH" ]; then
        missing_vars+=("SOLANA_PRIVATE_KEY or SOLANA_KEYPAIR_PATH")
    fi
    
    if [ -z "$RPC_URL_SOLANA_TESTNET" ]; then
        warnings+=("RPC_URL_SOLANA_TESTNET not set, will use default: https://api.devnet.solana.com")
    fi
    
    # Check EVM configuration
    if [ -z "$MNEMONIC" ] && [ -z "$PRIVATE_KEY" ]; then
        missing_vars+=("MNEMONIC or PRIVATE_KEY")
    fi
    
    if [ -z "$RPC_URL_SEPOLIA" ]; then
        warnings+=("RPC_URL_SEPOLIA not set, will use default: https://gateway.tenderly.co/public/sepolia")
    fi
    
    # Check optional variables
    if [ -z "$COMPUTE_UNIT_PRICE" ]; then
        warnings+=("COMPUTE_UNIT_PRICE not set, will use default: 1000")
    fi
    
    if [ -z "$INITIAL_AMOUNT" ]; then
        warnings+=("INITIAL_AMOUNT not set, will use default: 100000000000")
    fi
    
    if [ -z "$TOKEN_NAME" ]; then
        warnings+=("TOKEN_NAME not set, will use default: MyOFT")
    fi
    
    if [ -z "$TOKEN_SYMBOL" ]; then
        warnings+=("TOKEN_SYMBOL not set, will use default: MOFT")
    fi
    
    # Report missing variables
    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    # Report warnings
    if [ ${#warnings[@]} -ne 0 ]; then
        for warning in "${warnings[@]}"; do
            print_warning "$warning"
        done
    fi
    
    print_success "Environment configuration is valid"
    return 0
}

# Function to check Solana balance
check_solana_balance() {
    print_status "Checking Solana Balance"
    echo "=========================="
    
    if [ ! -f ".env" ]; then
        print_error ".env file not found"
        return 1
    fi
    
    source .env
    
    # Get Solana keypair
    local keypair_path=""
    if [ -n "$SOLANA_KEYPAIR_PATH" ]; then
        keypair_path="$SOLANA_KEYPAIR_PATH"
    elif [ -n "$SOLANA_PRIVATE_KEY" ]; then
        # Create temporary keypair file
        keypair_path="/tmp/solana_keypair.json"
        echo "$SOLANA_PRIVATE_KEY" > "$keypair_path"
    else
        print_error "No Solana keypair configured"
        return 1
    fi
    
    # Get public key
    local public_key=$(solana-keygen pubkey "$keypair_path" 2>/dev/null)
    if [ -z "$public_key" ]; then
        print_error "Failed to get Solana public key"
        return 1
    fi
    
    print_status "Solana address: $public_key"
    
    # Check balance
    local balance=$(solana balance "$public_key" -u devnet 2>/dev/null || echo "0")
    print_status "Balance: $balance SOL"
    
    # Check if balance is sufficient (need at least 5 SOL for deployment)
    local balance_num=$(echo "$balance" | sed 's/ SOL//')
    if (( $(echo "$balance_num < 5" | bc -l) )); then
        print_warning "Low balance detected. You need at least 5 SOL for deployment."
        print_status "You can get devnet SOL using: solana airdrop 5 -u devnet"
    else
        print_success "Sufficient balance for deployment"
    fi
    
    # Clean up temporary file
    if [ "$keypair_path" = "/tmp/solana_keypair.json" ]; then
        rm -f "$keypair_path"
    fi
}

# Function to check EVM balance
check_evm_balance() {
    print_status "Checking EVM Balance"
    echo "======================="
    
    if [ ! -f ".env" ]; then
        print_error ".env file not found"
        return 1
    fi
    
    source .env
    
    # Check if we have Node.js
    if ! command_exists node; then
        print_error "Node.js not found, cannot check EVM balance"
        return 1
    fi
    
    # Check if we have pnpm and node_modules
    if ! command_exists pnpm; then
        print_error "pnpm not found, cannot check EVM balance"
        return 1
    fi
    
    if [ ! -d "node_modules" ]; then
        print_warning "node_modules not found, installing dependencies..."
        pnpm install
    fi
    
    # Create temporary script to check balance
    cat > /tmp/check_balance.js << 'EOF'
const { ethers } = require('ethers');
require('dotenv').config();

async function checkBalance() {
    try {
        const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL_SEPOLIA || 'https://gateway.tenderly.co/public/sepolia');
        
        let wallet;
        if (process.env.PRIVATE_KEY) {
            wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
        } else if (process.env.MNEMONIC) {
            wallet = ethers.Wallet.fromMnemonic(process.env.MNEMONIC);
            wallet = wallet.connect(provider);
        } else {
            console.log('No wallet configuration found');
            return;
        }
        
        const balance = await wallet.getBalance();
        const balanceEth = ethers.utils.formatEther(balance);
        
        console.log(`Address: ${wallet.address}`);
        console.log(`Balance: ${balanceEth} ETH`);
        
        if (parseFloat(balanceEth) < 0.01) {
            console.log('WARNING: Low balance detected. You need at least 0.01 ETH for deployment.');
        } else {
            console.log('SUCCESS: Sufficient balance for deployment');
        }
    } catch (error) {
        console.log('ERROR: Failed to check balance:', error.message);
    }
}

checkBalance();
EOF
    
    # Run the balance check using the project's node_modules
    NODE_PATH=./node_modules node /tmp/check_balance.js
    
    # Clean up
    rm -f /tmp/check_balance.js
}

# Function to show help
show_help() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  check-prereqs      Check if all prerequisites are installed"
    echo "  create-env         Create .env file from template"
    echo "  validate-env       Validate environment configuration"
    echo "  check-solana       Check Solana balance and configuration"
    echo "  check-evm          Check EVM balance and configuration"
    echo "  setup-all          Run all setup checks"
    echo "  help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 check-prereqs"
    echo "  $0 create-env"
    echo "  $0 validate-env"
    echo "  $0 setup-all"
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    case $1 in
        "check-prereqs")
            check_prerequisites
            ;;
        "create-env")
            create_env_file
            ;;
        "validate-env")
            validate_environment
            ;;
        "check-solana")
            check_solana_balance
            ;;
        "check-evm")
            check_evm_balance
            ;;
        "setup-all")
            echo "Running complete environment setup..."
            echo ""
            check_prerequisites && echo ""
            create_env_file && echo ""
            validate_environment && echo ""
            check_solana_balance && echo ""
            check_evm_balance
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