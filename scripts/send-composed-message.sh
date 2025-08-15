#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_status() {
    echo -e "${BLUE}🔄 $1${NC}"
}

# Function to send composed message
send_composed_message() {
    local network="${1:-sepolia-testnet}"
    local dst_eid="${2:-40161}" # Default to Holesky testnet
    local amount="${3:-1000}"
    local recipient="${4:-0x6E3a149F0972F9810B46D50C95e81A88b3f38E80}"
    local message_type="${5:-CROSS_CHAIN_SEND}"
    local burnt_amount="${6}"
    
    print_status "Sending composed message with parameters:"
    echo "  Network: $network"
    echo "  Destination EID: $dst_eid"
    echo "  Amount: $amount"
    echo "  Recipient: $recipient"
    echo "  Message Type: $message_type"
    if [ -n "$burnt_amount" ]; then
        echo "  Burnt Amount: $burnt_amount"
    fi
    echo ""
    
    # Build command
    local cmd="pnpm hardhat --network $network lz:oft:send-composed --dst-eid $dst_eid --amount $amount --recipient $recipient --message-type $message_type"
    
    if [ -n "$burnt_amount" ]; then
        cmd="$cmd --burnt-amount $burnt_amount"
    fi
    
    print_status "Running command: $cmd"
    eval $cmd
    
    if [ $? -eq 0 ]; then
        print_success "Composed message sent successfully!"
    else
        print_error "Failed to send composed message"
        return 1
    fi
}

# Function to send cross-chain send message
send_cross_chain() {
    local network="${1:-sepolia-testnet}"
    local dst_eid="${2:-40161}"
    local amount="${3:-1000}"
    local recipient="${4:-0x6E3a149F0972F9810B46D50C95e81A88b3f38E80}"
    
    print_info "Sending CROSS_CHAIN_SEND message..."
    send_composed_message "$network" "$dst_eid" "$amount" "$recipient" "CROSS_CHAIN_SEND"
}

# Function to send burnt message
send_burnt_message() {
    local network="${1:-sepolia-testnet}"
    local dst_eid="${2:-40161}"
    local amount="${3:-1000}"
    local recipient="${4:-0x6E3a149F0972F9810B46D50C95e81A88b3f38E80}"
    local burnt_amount="${5:-500}"
    
    print_info "Sending BURNT message..."
    send_composed_message "$network" "$dst_eid" "$amount" "$recipient" "BURNT" "$burnt_amount"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  cross-chain     Send a CROSS_CHAIN_SEND composed message"
    echo "  burnt          Send a BURNT composed message"
    echo "  custom         Send a custom composed message with all parameters"
    echo "  help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 cross-chain sepolia-testnet 40161 1000"
    echo "  $0 burnt sepolia-testnet 40161 1000 0x6E3a149F0972F9810B46D50C95e81A88b3f38E80 500"
    echo "  $0 custom sepolia-testnet 40161 1000 0x6E3a149F0972F9810B46D50C95e81A88b3f38E80 CROSS_CHAIN_SEND"
    echo ""
    echo "Parameters:"
    echo "  network         Source network (default: sepolia-testnet)"
    echo "  dst_eid         Destination endpoint ID (default: 40161 for Holesky)"
    echo "  amount          Amount to send in token units (default: 1000)"
    echo "  recipient       Recipient address (default: 0x6E3a149F0972F9810B46D50C95e81A88b3f38E80)"
    echo "  burnt_amount    Amount that was burnt (only for BURNT messages)"
    echo ""
    echo "Common Endpoint IDs:"
    echo "  Sepolia Testnet: 40161"
    echo "  Holesky Testnet: 40217"
    echo "  Arbitrum Sepolia: 40231"
    echo "  Optimism Sepolia: 40232"
}

# Main script logic
case "${1:-help}" in
    "cross-chain")
        send_cross_chain "$2" "$3" "$4" "$5"
        ;;
    "burnt")
        send_burnt_message "$2" "$3" "$4" "$5" "$6"
        ;;
    "custom")
        send_composed_message "$2" "$3" "$4" "$5" "$6" "$7"
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
