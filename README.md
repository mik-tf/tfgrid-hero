# TFGrid Hero Deployment

This repository contains the infrastructure and configuration for deploying the Hero application (herolib backend + ui_colab frontend) on the ThreeFold Grid using OpenTofu and Ansible.

## Architecture

- **VM**: Single Ubuntu 24.04 VM on TFGrid with public IPv4
- **Backend**: Herolib server (Vlang) on port 8080
- **Frontend**: UI Colab (SvelteKit) served via Nginx on port 80/443
- **Database**: Redis servers on ports 6379 and 6381
- **Domain**: hero.projectmycelium.org

## Prerequisites

- OpenTofu or Terraform
- Ansible
- TFGrid account with mnemonics
- SSH key pair
- Domain DNS access (for hero.projectmycelium.org)

## Quick Start

1. **Clone and setup**:
   ```bash
   git clone <this-repo>
   cd tfgrid-hero
   cp infrastructure/credentials.auto.tfvars.example infrastructure/credentials.auto.tfvars
   cp .env.example .env
   ```

2. **Configure credentials**:
   Edit `infrastructure/credentials.auto.tfvars` with your TFGrid node ID.
   Edit `.env` with your domain and settings.

3. **Deploy complete stack**:
   ```bash
   export TF_VAR_mnemonic="your twelve word mnemonic"
   make deploy
   ```

   Or step by step:
   ```bash
   make infrastructure  # Deploy VM
   make inventory       # Generate Ansible inventory
   make wg             # Setup WireGuard (optional)
   make platform       # Deploy services
   make verify         # Verify deployment
   ```

4. **Configure DNS**:
   Point hero.projectmycelium.org to the VM's public IPv4 address.

## Local Development

For local testing, follow these steps:

1. Pull latest `development_heroserver` branch on herolib
2. Start Redis: `redis-server --port 6381` and `redis-server --port 6379`
3. Run herolib: `./examples/hero/heromodels/heroserver_example.vsh`
4. Start ui_colab: `make` (from main branch)

## Configuration

### Infrastructure Variables

- `node_id`: TFGrid node ID
- `cpu`: VM CPU cores (default: 2)
- `memory`: VM memory in MB (default: 4096)
- `ssh_key`: SSH public key

### Ansible Variables

- `domain_name`: Domain name (default: hero.projectmycelium.org)
- `enable_ssl`: Enable SSL with Let's Encrypt (default: false)
- `redis_password`: Redis password (auto-generated)
- `hero_backend_port`: Backend port (default: 8080)
- `ui_colab_port`: Frontend port (default: 3000)

## Services

- **herolib**: Backend API server
- **ui_colab**: Frontend web application
- **redis**: Data caching (ports 6379, 6381)
- **nginx**: Web server and reverse proxy
- **mycelium**: Network connectivity
- **fail2ban**: SSH protection

## Monitoring

Basic monitoring is included via systemd services and log rotation.

## Security

- UFW firewall with restricted SSH access
- fail2ban for SSH protection
- Redis with password authentication
- Optional SSL/TLS encryption

## Troubleshooting

- Check VM connectivity: `ssh root@<vm_ip>`
- View service status: `systemctl status <service>`
- Check logs: `journalctl -u <service>`
- Verify ports: `netstat -tlnp`

## Development

- Infrastructure: `infrastructure/main.tf`
- Ansible roles: `platform/roles/`
- Deployment scripts: `scripts/`
- Configuration templates: `platform/roles/*/templates/`