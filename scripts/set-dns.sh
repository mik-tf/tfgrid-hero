#!/bin/bash
# DNS Setup Script
# This script helps configure DNS records for the Hero app domain

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment configuration
load_env_config() {
    if [ -f "$PROJECT_ROOT/.env" ]; then
        set -a
        source "$PROJECT_ROOT/.env"
        set +a
    fi
}

# Get gateway IP
get_gateway_ip() {
    cd "$PROJECT_ROOT/infrastructure"

    if command -v tofu &> /dev/null; then
        TERRAFORM_CMD="tofu"
    elif command -v terraform &> /dev/null; then
        TERRAFORM_CMD="terraform"
    else
        log_error "Neither OpenTofu nor Terraform found"
        exit 1
    fi

    VM_IP=$($TERRAFORM_CMD output -raw vm_public_ip 2>/dev/null || echo "")
    if [ -z "$VM_IP" ]; then
        log_error "VM public IP not found. Run 'make infrastructure' first."
        exit 1
    fi

    # Strip subnet mask if present (e.g., 185.206.122.150/24 → 185.206.122.150)
    VM_IP=$(echo "$VM_IP" | cut -d'/' -f1)
}

# Display DNS requirements
display_dns_requirements() {
    log_info "DNS Configuration Required for Hero App"
    echo ""
    echo "Domain: $DOMAIN_NAME"
    echo "Gateway IP: $VM_IP"
    echo ""
    echo "Please create the following DNS A records with your DNS provider:"
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ Record Type │ Name                  │ Value          │ TTL   │"
    echo "├─────────────┼───────────────────────┼────────────────┼───────┤"
    printf "│ A           │ %-21s │ %-14s │ 300   │\n" "$DOMAIN_NAME" "$VM_IP"
    printf "│ A           │ %-21s │ %-14s │ 300   │\n" "api.$DOMAIN_NAME" "$VM_IP"
    printf "│ A           │ %-21s │ %-14s │ 300   │\n" "files.$DOMAIN_NAME" "$VM_IP"
    printf "│ A           │ %-21s │ %-14s │ 300   │\n" "ws.$DOMAIN_NAME" "$VM_IP"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    log_warning "Note: DNS propagation can take 5-30 minutes"
    echo ""
}

# Test DNS resolution
test_dns_resolution() {
    log_info "Testing DNS resolution..."

    local domains=("$DOMAIN_NAME" "api.$DOMAIN_NAME" "files.$DOMAIN_NAME" "ws.$DOMAIN_NAME")
    local all_resolved=true

    for domain in "${domains[@]}"; do
        log_info "Checking $domain..."
        local resolved_ip=$(dig +short "$domain" | head -1 || echo "")

        if [ -z "$resolved_ip" ]; then
            log_error "❌ $domain does not resolve to any IP"
            all_resolved=false
        elif [ "$resolved_ip" != "$VM_IP" ]; then
            log_error "❌ $domain resolves to $resolved_ip (expected $VM_IP)"
            all_resolved=false
        else
            log_success "✅ $domain correctly resolves to $VM_IP"
        fi
    done

    if [ "$all_resolved" = true ]; then
        log_success "All DNS records are correctly configured!"
        return 0
    else
        log_error "Some DNS records are not configured correctly."
        return 1
    fi
}

# Update .env file
update_env_file() {
    log_info "Updating .env file to mark DNS as configured..."

    # Use sed to replace DNS_RECORDS_SET=false with DNS_RECORDS_SET=true
    sed -i 's/DNS_RECORDS_SET=false/DNS_RECORDS_SET=true/' "$PROJECT_ROOT/.env"

    log_success "DNS_RECORDS_SET updated to true in .env"
}

# Main function
main() {
    echo "🌐 Hero App DNS Configuration"
    echo "============================"
    echo ""

    # Load configuration
    load_env_config

    # Validate domain
    if [ -z "${DOMAIN_NAME:-}" ]; then
        log_error "DOMAIN_NAME not set in .env file"
        exit 1
    fi

    # Get gateway IP
    get_gateway_ip

    # Display requirements
    display_dns_requirements

    # Ask user to confirm DNS setup
    echo "Have you configured these DNS records with your DNS provider?"
    echo ""
    read -p "Enter 'yes' to test DNS resolution and continue: " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "DNS setup cancelled. Run 'make set-dns' again when DNS is configured."
        exit 0
    fi

    # Test DNS resolution
    if test_dns_resolution; then
        update_env_file
        echo ""
        log_success "🎉 DNS configuration completed successfully!"
        echo ""
        echo "Next steps:"
        echo "  1. Run: make ssl-setup    (Setup SSL certificates)"
        echo "  2. Run: make verify       (Verify deployment)"
    else
        echo ""
        log_error "DNS configuration failed. Please check your DNS records and try again."
        echo ""
        echo "Troubleshooting:"
        echo "  - DNS changes can take 5-30 minutes to propagate"
        echo "  - Check your DNS provider's control panel"
        echo "  - Verify the records match exactly as shown above"
        echo "  - Run 'make set-dns' again to retest"
        exit 1
    fi
}

# Run main function
main "$@"