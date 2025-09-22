#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR="$SCRIPT_DIR/.."
INFRASTRUCTURE_DIR="$PROJECT_DIR/infrastructure"

echo -e "${GREEN}Hero App VM Addresses${NC}"
echo "===================="
echo ""

cd "$INFRASTRUCTURE_DIR"

# Check if terraform/tofu is available
if command -v tofu &> /dev/null; then
    TERRAFORM_CMD="tofu"
elif command -v terraform &> /dev/null; then
    TERRAFORM_CMD="terraform"
else
    echo -e "${RED}ERROR: Neither OpenTofu nor Terraform found${NC}"
    exit 1
fi

# Get all IP addresses from Terraform outputs (strip /24 from public IP)
VM_PUBLIC_IP=$($TERRAFORM_CMD output -raw vm_public_ip 2>/dev/null | sed 's|/.*||' || echo "N/A")
VM_WG_IP=$($TERRAFORM_CMD output -raw vm_wireguard_ip 2>/dev/null || echo "N/A")

# Get Mycelium IP if available
VM_MYCELIUM_IP=$($TERRAFORM_CMD output -raw vm_mycelium_ip 2>/dev/null || echo "N/A")

echo -e "${YELLOW}🌐 Public Access:${NC}"
if [ "$VM_PUBLIC_IP" != "N/A" ] && [ "$VM_PUBLIC_IP" != "null" ]; then
    echo "  Hero App: $VM_PUBLIC_IP"
else
    echo "  VM: Not deployed yet (run: make infrastructure)"
fi

echo ""

echo -e "${YELLOW}🔐 Private Networks (via WireGuard):${NC}"
if [ "$VM_WG_IP" != "N/A" ] && [ "$VM_WG_IP" != "null" ]; then
    echo "  VM: $VM_WG_IP"
fi

echo ""

echo -e "${YELLOW}🌍 Mycelium IPv6 Overlay:${NC}"
if [ "$VM_MYCELIUM_IP" != "N/A" ] && [ "$VM_MYCELIUM_IP" != "null" ]; then
    echo "  VM: $VM_MYCELIUM_IP"
else
    echo "  VM: Not assigned yet"
fi

echo ""

echo -e "${YELLOW}💡 Usage Tips:${NC}"
echo "  • Public websites work without VPN"
echo "  • SSH to private IPs requires VPN tunnel"
echo "  • Mycelium provides decentralized networking"

echo ""

echo -e "${YELLOW}🚀 Quick Commands:${NC}"
echo "  make ping         # Test VM connectivity"
echo "  make platform     # Deploy services to VMs"
echo "  make verify       # Verify deployment health"