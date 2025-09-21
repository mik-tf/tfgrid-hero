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
PLATFORM_DIR="$PROJECT_DIR/platform"

echo -e "${GREEN}Cleaning up Hero App deployment${NC}"
echo "==============================="

# Check if tofu/terraform is available
if command -v tofu &> /dev/null; then
    TERRAFORM_CMD="tofu"
elif command -v terraform &> /dev/null; then
    TERRAFORM_CMD="terraform"
else
    echo -e "${YELLOW}WARNING: Neither tofu nor terraform found. Skipping infrastructure destruction.${NC}"
    TERRAFORM_CMD=""
fi

if [[ -n "$TERRAFORM_CMD" ]]; then
    echo -e "${YELLOW}Destroying infrastructure with $TERRAFORM_CMD...${NC}"
    cd "$INFRASTRUCTURE_DIR"
    if $TERRAFORM_CMD destroy -auto-approve 2>/dev/null; then
        echo -e "${GREEN}✓ Infrastructure destroyed successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Infrastructure destruction failed or no resources to destroy${NC}"
    fi
    cd "$PROJECT_DIR"
fi

echo -e "${YELLOW}Removing Terraform and Ansible generated files...${NC}"

# Remove Terraform state files and Ansible generated files
FILES_TO_REMOVE=(
    "$INFRASTRUCTURE_DIR/state.json"
    "$INFRASTRUCTURE_DIR/terraform.tfstate"
    "$INFRASTRUCTURE_DIR/terraform.tfstate.backup"
    "$INFRASTRUCTURE_DIR/tfplan"
    "$INFRASTRUCTURE_DIR/hero.tfplan"
    "$INFRASTRUCTURE_DIR/.terraform.lock.hcl"
    "$PLATFORM_DIR/inventory.ini"
    "$PROJECT_DIR/wg-hero.conf"
)

for file in "${FILES_TO_REMOVE[@]}"; do
    if [[ -f "$file" ]]; then
        rm -f "$file"
        echo -e "${GREEN}✓ Removed $file${NC}"
    fi
done

# Remove .terraform directory
if [[ -d "$INFRASTRUCTURE_DIR/.terraform" ]]; then
    rm -rf "$INFRASTRUCTURE_DIR/.terraform"
    echo -e "${GREEN}✓ Removed $INFRASTRUCTURE_DIR/.terraform directory${NC}"
fi

# Remove local-mycelium directory if it exists
if [[ -d "$PROJECT_DIR/app/local-mycelium" ]]; then
    rm -rf "$PROJECT_DIR/app/local-mycelium"
    echo -e "${GREEN}✓ Removed $PROJECT_DIR/app/local-mycelium directory${NC}"
fi

echo ""
echo -e "${GREEN}Cleanup completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Note: This only removes local files and destroys cloud resources.${NC}"
echo -e "${YELLOW}Your source code and configuration files are preserved.${NC}"