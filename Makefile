.PHONY: help all deploy deploy-auto redeploy clean clean-auto infrastructure inventory platform verify health test ssl-setup set-dns address ping ssh-test

# Default target - complete Hero app deployment
all: deploy

# Help message
help:
	@echo "🚀 TFGrid Hero Deployment"
	@echo "========================"
	@echo ""
	@echo "🎯 Main Commands:"
	@echo "  make all             - Complete Hero app deployment (default)"
	@echo "  make deploy          - Deploy complete Hero app to TFGrid"
	@echo "  make deploy-auto     - Deploy without confirmation prompts"
	@echo "  make redeploy        - Redeploy Hero app services (after infrastructure exists)"
	@echo "  make infrastructure  - Deploy TFGrid infrastructure only"
	@echo "  make platform        - Deploy Hero app services only"
	@echo "  make set-dns         - Configure DNS records for domain"
	@echo "  make ssl-setup       - Setup SSL certificates for existing deployment"
	@echo "  make verify          - Verify deployment health"
	@echo "  make test            - Run comprehensive deployment tests"
	@echo "  make clean           - Clean up all TFGrid resources"
	@echo "  make clean-auto      - Clean up without confirmation prompts"
	@echo ""
	@echo "🔧 Development Commands:"
	@echo "  make inventory       - Generate Ansible inventory from infrastructure"
	@echo "  make health          - Check service health"
	@echo "  make address         - Show VM addresses and access information"
	@echo "  make ping            - Test connectivity to VMs"
	@echo "  make ssh-test        - Test SSH connectivity to VMs"
	@echo ""
	@echo "📋 Configuration:"
	@echo "  1. Copy infrastructure/credentials.auto.tfvars.example to infrastructure/credentials.auto.tfvars"
	@echo "  2. Copy .env.example to .env and configure your settings"
	@echo "  3. Set TF_VAR_mnemonic environment variable with your ThreeFold mnemonic"
	@echo "  4. Run: make deploy"
	@echo ""
	@echo "🌐 Environment Variables:"
	@echo "  TF_VAR_mnemonic        - ThreeFold mnemonic (required)"
	@echo "  DOMAIN_NAME            - Your domain for SSL (optional)"
	@echo "  ENABLE_SSL             - Enable SSL certificates (true/false)"
	@echo "  REDIS_PASSWORD         - Redis password"
	@echo ""
	@echo "🎯 Quick Start:"
	@echo "  export TF_VAR_mnemonic=\"your twelve word mnemonic here\""
	@echo "  export DOMAIN_NAME=\"hero.projectmycelium.org\""
	@echo "  export ENABLE_SSL=\"true\""
	@echo "  make deploy"

# Complete deployment workflow
deploy: infrastructure inventory wg platform
	@echo "🎉 Hero app deployment completed successfully!"
	@echo ""
	@echo "📍 Access your Hero app:"
	@if [ -f .env ] && grep -q "ENABLE_SSL=true" .env; then \
		DOMAIN=$$(grep DOMAIN_NAME .env | cut -d= -f2); \
		echo "🌐 Hero App: https://$$DOMAIN"; \
	else \
		VM_IP=$$(cd infrastructure && tofu output -raw vm_public_ip 2>/dev/null || echo "UNKNOWN"); \
		echo "🌐 Hero App: http://$$VM_IP"; \
	fi
	@echo ""
	@echo "📊 Management:"
	@VM_IP=$$(cd infrastructure && tofu output -raw vm_public_ip 2>/dev/null || echo "UNKNOWN"); \
	echo "🔍 Health: http://$$VM_IP/health"

# Auto-deployment without confirmation prompts
deploy-auto:
	@echo "🚀 Starting auto-deployment (no confirmation required)..."
	@export HERO_AUTO_DEPLOY=true && $(MAKE) deploy

# Auto-cleanup without confirmation prompts
clean-auto:
	@echo "🧹 Starting auto-cleanup (no confirmation required)..."
	@export HERO_AUTO_CLEAN=true && $(MAKE) clean

# Redeploy Hero app services (without infrastructure)
redeploy: inventory wg platform
	@echo "🔄 Hero app redeployment completed successfully!"
	@echo ""
	@echo "📍 Access your Hero app:"
	@if [ -f .env ] && grep -q "ENABLE_SSL=true" .env; then \
		DOMAIN=$$(grep DOMAIN_NAME .env | cut -d= -f2); \
		echo "🌐 Hero App: https://$$DOMAIN"; \
	else \
		VM_IP=$$(cd infrastructure && tofu output -raw vm_public_ip 2>/dev/null || echo "UNKNOWN"); \
		echo "🌐 Hero App: http://$$VM_IP"; \
	fi

# Deploy TFGrid infrastructure
infrastructure:
	@echo "🏗️ Deploying Hero app infrastructure to TFGrid..."
	@if [ -z "$$TF_VAR_mnemonic" ]; then \
		echo "❌ Error: TF_VAR_mnemonic environment variable is required"; \
		echo "   Set it with: export TF_VAR_mnemonic=\"your twelve word mnemonic\""; \
		exit 1; \
	fi
	@if [ ! -f infrastructure/credentials.auto.tfvars ]; then \
		echo "❌ Error: infrastructure/credentials.auto.tfvars not found"; \
		echo "   Copy from: cp infrastructure/credentials.auto.tfvars.example infrastructure/credentials.auto.tfvars"; \
		echo "   Then edit with your node ID"; \
		exit 1; \
	fi
	@./scripts/infrastructure.sh

# Generate Ansible inventory from Terraform outputs
inventory:
	@echo "📋 Generating Ansible inventory..."
	@./scripts/generate-inventory.sh

# Setup WireGuard connection to TFGrid
wg:
	@echo "🔐 Setting up WireGuard connection..."
	@./scripts/wg.sh

# Deploy Hero app services with Ansible
platform:
	@echo "🚀 Deploying Hero app services..."
	@if [ ! -f platform/inventory.ini ]; then \
		echo "❌ Error: Ansible inventory not found"; \
		echo "   Run: make inventory"; \
		exit 1; \
	fi
	@if [ ! -f .env ]; then \
		echo "⚠️ Warning: .env file not found, using defaults"; \
		echo "   For custom configuration: cp .env.example .env"; \
	fi
	@./scripts/platform.sh

# Setup SSL certificates
ssl-setup:
	@echo "🔒 Setting up SSL certificates..."
	@if [ -f .env ]; then set -a && . ./.env && set +a; fi; \
	if [ -z "$$DOMAIN_NAME" ]; then \
		echo "❌ Error: DOMAIN_NAME is required for SSL setup"; \
		echo "   Add to .env file: DOMAIN_NAME=hero.projectmycelium.org"; \
		exit 1; \
	fi; \
	if [ "$$ENABLE_SSL" != "true" ]; then \
		echo "❌ Error: ENABLE_SSL must be 'true' for SSL setup"; \
		echo "   Add to .env file: ENABLE_SSL=true"; \
		exit 1; \
	fi
	@./scripts/ssl-setup.sh

# Verify deployment health
verify:
	@echo "🔍 Verifying Hero app deployment..."
	@-./scripts/verify.sh

# Run comprehensive tests
test:
	@echo "🧪 Running Hero app deployment tests..."
	@./scripts/test.sh

# Check service health
health:
	@echo "💚 Checking Hero app service health..."
	@./scripts/health-check.sh

# Clean up TFGrid resources
clean:
	@echo "🧹 Cleaning up Hero app deployment..."
	@echo "⚠️ This will destroy ALL TFGrid resources for Hero app!"
	@if [ "${HERO_AUTO_CLEAN:-false}" = "true" ]; then \
		./scripts/clean.sh; \
	else \
		read -p "Are you sure? (y/N): " confirm; \
		if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
			./scripts/clean.sh; \
		else \
			echo "Cleanup cancelled"; \
		fi; \
	fi

# Set DNS
set-dns:
	@echo "🔄 Setting up DNS Records..."
	@./scripts/set-dns.sh

# Show VM addresses and access information
address:
	@echo "📍 Hero App VM Addresses..."
	@./scripts/address.sh

# Test connectivity to VMs
ping:
	@echo "🧪 Testing connectivity to VMs..."
	@./scripts/ping.sh

# Test SSH connectivity to VMs
ssh-test:
	@echo "🔑 Testing SSH connectivity to VMs..."
	@./scripts/ssh-test.sh

# Show deployment status
status:
	@echo "📊 Hero App Deployment Status"
	@echo "============================"
	@if [ -f infrastructure/terraform.tfstate ]; then \
		echo "🏗️ Infrastructure: ✅ Deployed"; \
		VM_IP=$$(cd infrastructure && tofu output -raw vm_public_ip 2>/dev/null || echo "UNKNOWN"); \
		echo "📍 VM IP: $$VM_IP"; \
	else \
		echo "🏗️ Infrastructure: ❌ Not deployed"; \
	fi
	@if [ -f platform/inventory.ini ]; then \
		echo "📋 Inventory: ✅ Generated"; \
	else \
		echo "📋 Inventory: ❌ Not generated"; \
	fi