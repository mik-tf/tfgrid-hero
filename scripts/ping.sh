#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR="$SCRIPT_DIR/.."
INFRASTRUCTURE_DIR="$PROJECT_DIR/infrastructure"

echo -e "${GREEN}Testing connectivity to Hero App VM${NC}"
echo "==================================="

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

VM_PUBLIC_IP=$($TERRAFORM_CMD output -json vm_public_ip 2>/dev/null | jq -r . 2>/dev/null | cut -d'/' -f1 || echo "")
VM_WG_IP=$($TERRAFORM_CMD output -json vm_wireguard_ip 2>/dev/null | jq -r . 2>/dev/null || echo "")

# Get Mycelium IPv6 address
VM_MYCELIUM_IP=$($TERRAFORM_CMD output -json vm_mycelium_ip 2>/dev/null | jq -r . 2>/dev/null || echo "")

if [[ -z "$VM_PUBLIC_IP" || "$VM_PUBLIC_IP" == "null" ]]; then
    echo -e "${YELLOW}WARNING: Could not get VM IP from Terraform outputs${NC}"
    echo -e "${YELLOW}This is normal if infrastructure hasn't been deployed yet${NC}"
    echo ""
    echo -e "${YELLOW}To deploy infrastructure:${NC}"
    echo "  make infrastructure"
    echo "  make inventory"
    echo ""
    echo -e "${GREEN}No VM to test${NC}"
    exit 0
fi

echo -e "${YELLOW}Testing IPv4 public connectivity...${NC}"

# Test IPv4 public connectivity
echo -n "Hero VM ($VM_PUBLIC_IP): "
if ping -c 3 -W 2 "$VM_PUBLIC_IP" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Reachable${NC}"
else
    echo -e "${RED}✗ Unreachable${NC}"
fi

echo ""
echo -e "${YELLOW}Testing SSH connectivity...${NC}"

# Test SSH connectivity
echo -n "SSH to VM ($VM_PUBLIC_IP): "
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$VM_PUBLIC_IP "echo 'SSH OK'" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ SSH accessible${NC}"
else
    echo -e "${RED}✗ SSH unreachable${NC}"
fi

echo ""
echo -e "${YELLOW}Testing Mycelium IPv6 connectivity...${NC}"

# Test Mycelium connectivity
if [[ -n "$VM_MYCELIUM_IP" && "$VM_MYCELIUM_IP" != "null" ]]; then
    echo -n "Hero VM ($VM_MYCELIUM_IP): "
    if ping6 -c 3 -W 2 "$VM_MYCELIUM_IP" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Reachable${NC}"
    else
        echo -e "${RED}✗ Unreachable${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Connectivity test completed${NC}"