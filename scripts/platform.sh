#!/bin/bash
# Hero App Platform Deployment Script
# This script deploys Hero app services using Ansible

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking platform deployment prerequisites..."
    
    # Check if Ansible is installed
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "Ansible is not installed"
        echo "Install Ansible:"
        echo "  Ubuntu/Debian: sudo apt install ansible"
        echo "  CentOS/RHEL: sudo yum install ansible"
        echo "  macOS: brew install ansible"
        echo "  pip: pip install ansible"
        exit 1
    fi
    
    # Check Ansible version
    ANSIBLE_VERSION=$(ansible --version | head -1 | cut -d' ' -f2)
    log_info "Using Ansible version: $ANSIBLE_VERSION"
    
    # Check if inventory exists
    if [ ! -f "$PLATFORM_DIR/inventory.ini" ]; then
        log_error "Ansible inventory not found"
        log_error "Run: make inventory"
        exit 1
    fi
    
    # Check WireGuard connection
    if ! sudo wg show hero >/dev/null 2>&1; then
        log_error "WireGuard connection not established"
        log_error "Run: make wireguard"
        exit 1
    fi
    
    log_success "Platform deployment prerequisites check passed"
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
        NETWORK_MODE="${NETWORK_MODE:-both}"
        GATEWAY_TYPE="${GATEWAY_TYPE:-gateway_proxy}"
        ENABLE_SSL="${ENABLE_SSL:-false}"
        ENABLE_MONITORING="${ENABLE_MONITORING:-true}"
    fi
    
    # Generate secure passwords if not provided
    if [ -z "${POSTGRES_PASSWORD:-}" ]; then
        POSTGRES_PASSWORD=$(openssl rand -base64 32)
        log_warning "Generated random PostgreSQL password"
    fi
    
    if [ -z "${REDIS_PASSWORD:-}" ]; then
        REDIS_PASSWORD=$(openssl rand -base64 32)
        log_warning "Generated random Redis password"
    fi
    
    if [ -z "${JWT_SECRET:-}" ]; then
        JWT_SECRET=$(openssl rand -hex 32)
        log_warning "Generated random JWT secret"
    fi
}

# Test Ansible connectivity
test_ansible_connectivity() {
    log_info "Testing Ansible connectivity to Hero VMs..."
    
    cd "$PLATFORM_DIR"
    
    # Test connection to all VMs
    if ansible all -i inventory.ini -m ping --one-line; then
        log_success "Ansible connectivity test passed"
    else
        log_error "Ansible connectivity test failed"
        echo ""
        echo "🔧 Troubleshooting:"
        echo "1. Ensure WireGuard is connected: make wireguard"
        echo "2. Wait for VMs to boot completely (2-3 minutes after infrastructure deployment)"
        echo "3. Check VM status on TFGrid dashboard"
        echo "4. Verify SSH key is correct in infrastructure/credentials.auto.tfvars"
        exit 1
    fi
}

# Install Ansible dependencies
install_ansible_dependencies() {
    log_info "Installing Ansible dependencies..."
    
    cd "$PLATFORM_DIR"
    
    # Check if requirements.yml exists
    if [ -f "requirements.yml" ]; then
        ansible-galaxy install -r requirements.yml --force
        log_success "Ansible roles installed"
    else
        log_info "No requirements.yml found, skipping role installation"
    fi
    
    # Check if collection requirements exist
    if [ -f "requirements-collections.yml" ]; then
        ansible-galaxy collection install -r requirements-collections.yml --force
        log_success "Ansible collections installed"
    else
        log_info "No collection requirements found"
    fi
}

# Run pre-deployment checks
pre_deployment_checks() {
    log_info "Running pre-deployment checks..."
    
    cd "$PLATFORM_DIR"
    
    # Validate inventory
    if ansible-inventory -i inventory.ini --list >/dev/null 2>&1; then
        log_success "Inventory validation passed"
    else
        log_error "Inventory validation failed"
        exit 1
    fi
    
    # Check if all VMs are reachable
    UNREACHABLE=$(ansible all -i inventory.ini -m ping --one-line 2>&1 | grep -c "UNREACHABLE" || true)
    if [ "$UNREACHABLE" -gt 0 ]; then
        log_error "$UNREACHABLE VMs are unreachable"
        log_error "Ensure all VMs are booted and WireGuard is connected"
        exit 1
    fi
    
    log_success "Pre-deployment checks passed"
}

# Deploy Hero app services
deploy_services() {
    log_info "Deploying Hero app services to TFGrid VMs..."
    
    cd "$PLATFORM_DIR"
    
    # Build extra vars for Ansible
    EXTRA_VARS=""
    EXTRA_VARS="${EXTRA_VARS} network_mode=${NETWORK_MODE:-both}"
    EXTRA_VARS="${EXTRA_VARS} gateway_type=${GATEWAY_TYPE:-gateway_proxy}"
    EXTRA_VARS="${EXTRA_VARS} enable_ssl=${ENABLE_SSL:-false}"
    EXTRA_VARS="${EXTRA_VARS} enable_monitoring=${ENABLE_MONITORING:-true}"
    EXTRA_VARS="${EXTRA_VARS} postgres_password=${POSTGRES_PASSWORD}"
    EXTRA_VARS="${EXTRA_VARS} redis_password=${REDIS_PASSWORD}"
    EXTRA_VARS="${EXTRA_VARS} jwt_secret=${JWT_SECRET}"
    
    # Add SSL configuration if enabled
    if [ "${ENABLE_SSL:-false}" = "true" ] && [ -n "${DOMAIN_NAME:-}" ]; then
        EXTRA_VARS="${EXTRA_VARS} domain_name=${DOMAIN_NAME}"
        EXTRA_VARS="${EXTRA_VARS} ssl_email=${SSL_EMAIL:-admin@${DOMAIN_NAME}}"
        EXTRA_VARS="${EXTRA_VARS} ssl_staging=${SSL_STAGING:-false}"
    fi
    
    # Show deployment configuration
    echo ""
    echo "🎯 Deployment Configuration:"
    echo "============================"
    echo "   Network Mode:    ${NETWORK_MODE:-both}"
    echo "   Gateway Type:    ${GATEWAY_TYPE:-gateway_proxy}"
    echo "   SSL Enabled:     ${ENABLE_SSL:-false}"
    echo "   Monitoring:      ${ENABLE_MONITORING:-true}"
    if [ "${ENABLE_SSL:-false}" = "true" ] && [ -n "${DOMAIN_NAME:-}" ]; then
        echo "   Domain:          ${DOMAIN_NAME}"
    fi
    echo ""
    
    # Run Ansible playbook
    log_info "Executing Ansible playbook..."
    
    if ansible-playbook -i inventory.ini site.yml --extra-vars "$EXTRA_VARS" -v; then
        log_success "Hero app services deployed successfully"
    else
        log_error "Hero app service deployment failed"
        echo ""
        echo "🔧 Troubleshooting:"
        echo "1. Check individual VM connectivity: ansible all -i inventory.ini -m ping"
        echo "2. Check service logs: make logs"
        echo "3. Verify configuration: cat .env"
        echo "4. Re-run deployment: make platform"
        exit 1
    fi
}

# Show deployment summary
show_deployment_summary() {
    log_info "Deployment summary:"
    
    cd "$PLATFORM_DIR"
    
    echo ""
    echo "🚀 Hero App Services Deployed:"
    echo "=============================="
    
    # Get VM IPs from inventory
    GATEWAY_IP=$(ansible-inventory -i inventory.ini --list | jq -r '.gateway.hosts[0]' 2>/dev/null || echo "unknown")
    GATEWAY_PUBLIC_IP=$(ansible-inventory -i inventory.ini --host gateway | jq -r '.public_ip' 2>/dev/null || echo "unknown")
    
    echo "📍 Access Points:"
    if [ "${ENABLE_SSL:-false}" = "true" ] && [ -n "${DOMAIN_NAME:-}" ]; then
        echo "   🌐 Hero App:    https://${DOMAIN_NAME}"
        echo "   🔌 API:         https://api.${DOMAIN_NAME}"
        echo "   📦 Files:       https://files.${DOMAIN_NAME}"
        echo "   🔗 WebSocket:   wss://ws.${DOMAIN_NAME}"
    else
        echo "   🌐 Hero App:    http://${GATEWAY_PUBLIC_IP}"
        echo "   🔌 API:         http://${GATEWAY_PUBLIC_IP}/api"
        echo "   📦 Files:       http://${GATEWAY_PUBLIC_IP}/ipfs"
        echo "   🔗 WebSocket:   ws://${GATEWAY_PUBLIC_IP}/ws"
    fi
    
    echo ""
    echo "📊 Management Interfaces:"
    echo "   📈 Monitoring:  http://${GATEWAY_PUBLIC_IP}/grafana"
    echo "   🔍 Health:      http://${GATEWAY_PUBLIC_IP}/health"
    echo "   📊 Metrics:     http://${GATEWAY_PUBLIC_IP}/prometheus"
    
    echo ""
    echo "🔧 Service Distribution:"
    echo "   🌐 Gateway:     ${GATEWAY_IP} (NGINX, SSL, Load Balancing)"
    echo "   🗄️ Database:    $(ansible-inventory -i inventory.ini --list | jq -r '.database.hosts[0]' 2>/dev/null || echo "unknown") (PostgreSQL, PostgREST, Redis)"
    echo "   📦 Storage:     $(ansible-inventory -i inventory.ini --list | jq -r '.storage.hosts[0]' 2>/dev/null || echo "unknown") (IPFS Cluster)"
    echo "   🚀 App:         $(ansible-inventory -i inventory.ini --list | jq -r '.app.hosts[0]' 2>/dev/null || echo "unknown") (React Frontend, Node.js Services)"
    
    echo ""
    echo "🎯 Next Steps:"
    echo "1. Run: make verify       (Verify all services are healthy)"
    echo "2. Run: make ssl-setup    (If you want to add SSL later)"
    echo "3. Run: make test         (Run comprehensive tests)"
    echo "4. Run: make monitor      (Open monitoring dashboard)"
}

# Save deployment configuration
save_deployment_config() {
    log_info "Saving deployment configuration..."
    
    cat > "$PROJECT_ROOT/deployment-info.json" << EOF
{
    "deployment_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "network_mode": "${NETWORK_MODE:-both}",
    "gateway_type": "${GATEWAY_TYPE:-gateway_proxy}",
    "ssl_enabled": ${ENABLE_SSL:-false},
    "domain_name": "${DOMAIN_NAME:-}",
    "monitoring_enabled": ${ENABLE_MONITORING:-true},
    "gateway_public_ip": "${GATEWAY_PUBLIC_IP:-}",
    "services": {
        "gateway": "nginx, ssl, load_balancing, monitoring",
        "database": "postgresql, postgrest, redis",
        "storage": "ipfs, ipfs_cluster",
        "app": "react_frontend, auth_service, websocket_service"
    }
}
EOF
    
    log_success "Deployment configuration saved to deployment-info.json"
}

# Main function
main() {
    echo "🚀 Hero App Platform Deployment"
    echo "==============================="
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Load environment configuration
    load_env_config
    
    # Install Ansible dependencies
    install_ansible_dependencies
    
    # Test Ansible connectivity
    test_ansible_connectivity
    
    # Run pre-deployment checks
    pre_deployment_checks
    
    # Deploy services
    deploy_services
    
    # Save deployment configuration
    save_deployment_config
    
    # Show deployment summary
    show_deployment_summary
    
    echo ""
    log_success "🎉 Hero app platform deployment completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    "check")
        check_prerequisites
        load_env_config
        test_ansible_connectivity
        pre_deployment_checks
        log_success "All platform deployment checks passed"
        ;;
    "gateway-only")
        log_info "Deploying gateway services only..."
        cd "$PLATFORM_DIR"
        load_env_config
        ansible-playbook -i inventory.ini site.yml --limit gateway --extra-vars "network_mode=${NETWORK_MODE:-both} gateway_type=${GATEWAY_TYPE:-gateway_proxy} enable_ssl=${ENABLE_SSL:-false}"
        ;;
    "database-only")
        log_info "Deploying database services only..."
        cd "$PLATFORM_DIR"
        load_env_config
        ansible-playbook -i inventory.ini site.yml --limit database --extra-vars "postgres_password=${POSTGRES_PASSWORD} redis_password=${REDIS_PASSWORD} jwt_secret=${JWT_SECRET}"
        ;;
    "storage-only")
        log_info "Deploying storage services only..."
        cd "$PLATFORM_DIR"
        load_env_config
        ansible-playbook -i inventory.ini site.yml --limit storage --extra-vars "network_mode=${NETWORK_MODE:-both}"
        ;;
    "app-only")
        log_info "Deploying app services only..."
        cd "$PLATFORM_DIR"
        load_env_config
        ansible-playbook -i inventory.ini site.yml --limit app --extra-vars "network_mode=${NETWORK_MODE:-both} enable_ssl=${ENABLE_SSL:-false} domain_name=${DOMAIN_NAME:-}"
        ;;
    *)
        main "$@"
        ;;
esac