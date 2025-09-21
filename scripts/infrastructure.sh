#!/bin/bash
# Hero App Infrastructure Deployment Script
# This script deploys the complete Hero app infrastructure to ThreeFold Grid

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INFRASTRUCTURE_DIR="$PROJECT_ROOT/infrastructure"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if OpenTofu/Terraform is installed
    if ! command -v tofu &> /dev/null && ! command -v terraform &> /dev/null; then
        log_error "Neither OpenTofu nor Terraform is installed"
        log_error "Install OpenTofu: https://opentofu.org/docs/intro/install/"
        exit 1
    fi
    
    # Prefer OpenTofu over Terraform
    if command -v tofu &> /dev/null; then
        TERRAFORM_CMD="tofu"
        log_info "Using OpenTofu"
    else
        TERRAFORM_CMD="terraform"
        log_info "Using Terraform"
    fi
    
    # Check mnemonic
    if [ -z "${TF_VAR_mnemonic:-}" ]; then
        log_error "TF_VAR_mnemonic environment variable is required"
        log_error "Set it with: export TF_VAR_mnemonic=\"your twelve word mnemonic\""
        exit 1
    fi
    
    # Check credentials file
    if [ ! -f "$INFRASTRUCTURE_DIR/credentials.auto.tfvars" ]; then
        log_error "Credentials file not found: $INFRASTRUCTURE_DIR/credentials.auto.tfvars"
        log_error "Copy from: cp infrastructure/credentials.auto.tfvars.example infrastructure/credentials.auto.tfvars"
        log_error "Then edit with your ThreeFold Grid node IDs"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Initialize Terraform/OpenTofu
init_terraform() {
    log_info "Initializing $TERRAFORM_CMD..."
    
    cd "$INFRASTRUCTURE_DIR"
    
    if [ ! -d ".terraform" ] || [ ! -f ".terraform.lock.hcl" ]; then
        $TERRAFORM_CMD init
        log_success "$TERRAFORM_CMD initialized"
    else
        log_info "$TERRAFORM_CMD already initialized"
    fi
}

# Plan infrastructure deployment
plan_infrastructure() {
    log_info "Planning infrastructure deployment..."
    
    cd "$INFRASTRUCTURE_DIR"
    
    $TERRAFORM_CMD plan -out=hero.tfplan
    
    if [ $? -eq 0 ]; then
        log_success "Infrastructure plan created successfully"
    else
        log_error "Infrastructure planning failed"
        exit 1
    fi
}

# Apply infrastructure deployment
apply_infrastructure() {
    log_info "Applying infrastructure deployment to TFGrid..."
    
    cd "$INFRASTRUCTURE_DIR"
    
    # Show what will be deployed
    echo "🎯 Deploying Hero app infrastructure with the following configuration:"
    $TERRAFORM_CMD show -json hero.tfplan | jq -r '
        .planned_values.root_module.resources[] | 
        select(.type == "grid_deployment") | 
        "VM: \(.values.name) on node \(.values.node) (\(.values.vms[0].cpu) CPU, \(.values.vms[0].memory)MB RAM)"
    ' 2>/dev/null || echo "   (Plan details not available)"
    
    echo ""

    # Check if auto-deployment is enabled
    if [ "${HERO_AUTO_DEPLOY:-false}" = "true" ]; then
        log_info "Auto-deployment enabled, proceeding without confirmation..."
        REPLY="y"
    else
        read -p "🚀 Proceed with deployment? (y/N): " -n 1 -r
        echo
    fi

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Starting deployment..."
        
        # Apply with auto-approve in CI/CD environments
        if [ "${CI:-false}" = "true" ]; then
            $TERRAFORM_CMD apply -auto-approve hero.tfplan
        else
            $TERRAFORM_CMD apply hero.tfplan
        fi
        
        if [ $? -eq 0 ]; then
            log_success "Infrastructure deployment completed successfully"
        else
            log_error "Infrastructure deployment failed"
            exit 1
        fi
    else
        log_warning "Deployment cancelled by user"
        exit 0
    fi
}

# Global variables for VM information
VM_PUBLIC_IP=""

# Display deployment results
show_results() {
    log_info "Deployment results:"

    cd "$INFRASTRUCTURE_DIR"

    echo ""
    echo "🌐 VM Information:"
    echo "=================="

    # Extract and display VM information (strip /24 from public IP)
    VM_PUBLIC_IP=$($TERRAFORM_CMD output -raw vm_public_ip 2>/dev/null | sed 's|/.*||' || echo "N/A")
    VM_WG_IP=$($TERRAFORM_CMD output -raw vm_wireguard_ip 2>/dev/null || echo "N/A")
    VM_MYC_IP=$($TERRAFORM_CMD output -raw vm_mycelium_ip 2>/dev/null || echo "N/A")

    echo "🚀 Hero VM:"
    echo "   Public IPv4: $VM_PUBLIC_IP"
    echo "   WireGuard:   $VM_WG_IP"
    echo "   Mycelium:    $VM_MYC_IP"
    echo ""

    # Save WireGuard config
    log_info "Saving WireGuard configuration..."
    $TERRAFORM_CMD output -raw wg_config > "$PROJECT_ROOT/wg-hero.conf"
    log_success "WireGuard config saved to wg-hero.conf"

    echo ""
    echo "🎯 Next Steps:"
    echo "1. Run: make inventory    (Generate Ansible inventory)"
    echo "2. Run: make wg           (Setup WireGuard connection)"
    echo "3. Run: make platform     (Deploy Hero app services)"
    echo "4. Run: make verify       (Verify deployment)"
    echo ""
    echo "🚀 Or run complete deployment: make deploy"
}

# Cleanup function for error handling
cleanup_on_error() {
    log_error "Deployment failed, cleaning up..."
    cd "$INFRASTRUCTURE_DIR"
    
    if [ -f "hero.tfplan" ]; then
        rm -f hero.tfplan
        log_info "Removed failed deployment plan"
    fi
}

# Main deployment function
main() {
    echo "🚀 Hero App Infrastructure Deployment"
    echo "===================================="
    echo ""
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Check prerequisites
    check_prerequisites
    
    # Initialize Terraform/OpenTofu
    init_terraform
    
    # Plan deployment
    plan_infrastructure
    
    # Apply deployment
    apply_infrastructure
    
    # Show results
    show_results
    
    echo ""
    log_success "🎉 Hero app infrastructure deployment completed successfully!"
    echo ""
    echo "📍 Your Hero app is available at: $VM_PUBLIC_IP"
    echo "🔧 Continue with: make platform"
}

# Run main function
main "$@"