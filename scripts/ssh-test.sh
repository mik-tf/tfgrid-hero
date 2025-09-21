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

echo -e "${GREEN}Testing SSH connectivity to Hero App VM${NC}"
echo "========================================"

# Get VM IPs from Terraform outputs
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

VM_PUBLIC_IP=$($TERRAFORM_CMD output -raw vm_public_ip 2>/dev/null | sed 's|/.*||' || echo "")
VM_WG_IP=$($TERRAFORM_CMD output -raw vm_wireguard_ip 2>/dev/null || echo "")

# Get Mycelium IPv6 address
VM_MYCELIUM_IP=$($TERRAFORM_CMD output -raw vm_mycelium_ip 2>/dev/null || echo "")

if [[ -z "$VM_PUBLIC_IP" || "$VM_PUBLIC_IP" == "null" ]]; then
    echo -e "${RED}ERROR: Could not get VM IP from Terraform outputs${NC}"
    echo "Have you deployed the infrastructure yet?"
    exit 1
fi

echo -e "${YELLOW}Testing SSH via IPv4 public...${NC}"

# Test SSH via IPv4 public
echo -n "SSH to VM ($VM_PUBLIC_IP): "
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"$VM_PUBLIC_IP" "echo 'SSH OK'" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ SSH OK${NC}"
else
    echo -e "${RED}✗ SSH Failed${NC}"
fi

echo ""
echo -e "${YELLOW}Testing SSH via Mycelium IPv6...${NC}"

# Test SSH via Mycelium IPv6 (if available)
if [[ -n "$VM_MYCELIUM_IP" && "$VM_MYCELIUM_IP" != "null" ]]; then
    echo -n "SSH to VM ($VM_MYCELIUM_IP): "
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"[$VM_MYCELIUM_IP]" "echo 'SSH OK'" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ SSH OK${NC}"
    else
        echo -e "${RED}✗ SSH Failed${NC}"
    fi
fi

echo ""
echo -e "${GREEN}SSH connectivity test completed${NC}"