#!/bin/bash
# Generate Ansible Inventory from TFGrid Infrastructure Outputs
# This script creates the Ansible inventory.ini file from Terraform/OpenTofu outputs

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INFRASTRUCTURE_DIR="$PROJECT_ROOT/infrastructure"
PLATFORM_DIR="$PROJECT_ROOT/platform"

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

# Check if infrastructure is deployed
check_infrastructure() {
    if [ ! -f "$INFRASTRUCTURE_DIR/terraform.tfstate" ] && [ ! -f "$INFRASTRUCTURE_DIR/terraform.tfstate.backup" ]; then
        log_error "No infrastructure state found"
        log_error "Run: tofu apply"
        exit 1
    fi

    cd "$INFRASTRUCTURE_DIR"

    # Check if OpenTofu/Terraform is available
    if command -v tofu &> /dev/null; then
        TERRAFORM_CMD="tofu"
    elif command -v terraform &> /dev/null; then
        TERRAFORM_CMD="terraform"
    else
        log_error "Neither OpenTofu nor Terraform found"
        exit 1
    fi
}

# Extract VM information from Terraform outputs
extract_vm_info() {
    log_info "Extracting VM information from infrastructure state..."

    cd "$INFRASTRUCTURE_DIR"

    # Extract VM details (strip /24 from public IP for compatibility)
    VM_PUBLIC_IP=$($TERRAFORM_CMD output -raw vm_public_ip 2>/dev/null | sed 's|/.*||' || echo "")
    VM_WG_IP=$($TERRAFORM_CMD output -raw vm_wireguard_ip 2>/dev/null || echo "")
    VM_MYC_IP=$($TERRAFORM_CMD output -raw vm_mycelium_ip 2>/dev/null || echo "")

    # Validate that we got the required information
    if [ -z "$VM_PUBLIC_IP" ] || [ -z "$VM_WG_IP" ]; then
        log_error "Failed to extract VM information"
        exit 1
    fi

    log_success "VM information extracted successfully"
}

# Load environment configuration
load_env_config() {
    # Load .env file if it exists
    if [ -f "$PROJECT_ROOT/.env" ]; then
        log_info "Loading configuration from .env file..."
        set -a
        source "$PROJECT_ROOT/.env"
        set +a
    else
        log_warning ".env file not found, using defaults"
        # Set default values
        MAIN_NETWORK="${MAIN_NETWORK:-wireguard}"
        NETWORK_MODE="${NETWORK_MODE:-both}"
        GATEWAY_TYPE="${GATEWAY_TYPE:-nginx}"
        ENABLE_SSL="${ENABLE_SSL:-false}"
    fi
}

# Generate Ansible inventory
generate_inventory() {
    log_info "Generating Ansible inventory..."

    # Choose which IP addresses to use for Ansible connectivity
    case "${MAIN_NETWORK:-wireguard}" in
        "wireguard")
            VM_ANSIBLE_IP="$VM_WG_IP"
            log_info "Using WireGuard IP for Ansible connectivity"
            ;;
        "mycelium")
            VM_ANSIBLE_IP="$VM_MYC_IP"
            log_info "Using Mycelium IP for Ansible connectivity"
            ;;
        "ipv4")
            VM_ANSIBLE_IP="$VM_PUBLIC_IP"
            log_info "Using IPv4 public IP for Ansible connectivity"
            ;;
        *)
            log_error "Invalid MAIN_NETWORK: ${MAIN_NETWORK}. Use 'wireguard', 'mycelium', or 'ipv4'"
            exit 1
            ;;
    esac

    # Create inventory file
    cat > "$PLATFORM_DIR/inventory.ini" << EOF
# Hero App Ansible Inventory
# Generated on $(date)
# Network: ${MAIN_NETWORK:-wireguard}

[hero]
hero ansible_host=${VM_ANSIBLE_IP} ansible_user=root ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' public_ip=${VM_PUBLIC_IP} wireguard_ip=${VM_WG_IP} mycelium_ip=${VM_MYC_IP}

[hero:vars]
# Network configuration
network_mode=${NETWORK_MODE:-both}
main_network=${MAIN_NETWORK:-wireguard}

# SSL configuration
enable_ssl=${ENABLE_SSL:-false}
domain_name=${DOMAIN_NAME:-hero.projectmycelium.org}
ssl_email=${SSL_EMAIL:-admin@${DOMAIN_NAME:-hero.projectmycelium.org}}
ssl_staging=${SSL_STAGING:-false}

# Security configuration
redis_password=${REDIS_PASSWORD:-$(openssl rand -base64 32)}

# Resource configuration
cpu=${CPU:-2}
memory=${MEMORY:-4096}

# Hero app configuration
hero_backend_port=8080
ui_colab_port=3000
EOF

    log_success "Ansible inventory generated: $PLATFORM_DIR/inventory.ini"
}

# Display inventory information
show_inventory() {
    echo ""
    echo "📋 Generated Inventory Information:"
    echo "=================================="
    echo ""
    echo "🚀 Hero VM:"
    echo "   Public IP:     $VM_PUBLIC_IP"
    echo "   Ansible IP:    $VM_ANSIBLE_IP"
    echo "   WireGuard IP:  $VM_WG_IP"
    echo "   Mycelium IP:   $VM_MYC_IP"
    echo ""
    echo "🔧 Configuration:"
    echo "   Main Network:  ${MAIN_NETWORK:-wireguard}"
    echo "   Network Mode:  ${NETWORK_MODE:-both}"
    echo "   SSL Enabled:   ${ENABLE_SSL:-false}"
    if [ "${ENABLE_SSL:-false}" = "true" ] && [ -n "${DOMAIN_NAME:-}" ]; then
        echo "   Domain:        ${DOMAIN_NAME}"
    fi
    echo ""
    echo "🎯 Next Steps:"
    echo "1. Run: ansible-playbook -i platform/inventory.ini platform/playbook.yml"
}

# Main function
main() {
    echo "📋 Hero App Inventory Generation"
    echo "==============================="
    echo ""

    # Check infrastructure
    check_infrastructure

    # Load environment configuration
    load_env_config

    # Extract VM information
    extract_vm_info

    # Generate inventory
    generate_inventory

    # Show inventory information
    show_inventory

    echo ""
    log_success "🎉 Ansible inventory generated successfully!"
}

# Run main function
main "$@"