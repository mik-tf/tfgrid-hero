terraform {
  required_providers {
    grid = {
      source  = "threefoldtech/grid"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "grid" {
  mnemonic = var.mnemonic
  network   = var.tfgrid_network
  relay_url = var.tfgrid_network == "main" ? "wss://relay.grid.tf" : "wss://relay.test.grid.tf"
}

variable "mnemonic" {
  type        = string
  description = "The mnemonic of the account"
}

variable "tfgrid_network" {
  type        = string
  default     = "main"
  description = "ThreeFold Grid network (main, test, dev)"

  validation {
    condition     = contains(["main", "test", "dev"], var.tfgrid_network)
    error_message = "Network must be one of: main, test, dev"
  }
}

# Generate mycelium key for the VM
resource "random_bytes" "mycelium_key" {
  length = 32
}

# Generate mycelium IP seed
resource "random_bytes" "mycelium_ip_seed" {
  length = 6
}

# Hero network with mycelium and WireGuard support
resource "grid_network" "hero_network" {
  name          = "hero_net"
  nodes         = [var.node_id]
  ip_range      = "10.1.0.0/16"
  add_wg_access = true
  mycelium_keys = {
    (tostring(var.node_id)) = random_bytes.mycelium_key.hex
  }
}

# Hero VM (herolib backend + ui_colab frontend + redis + nginx)
resource "grid_deployment" "hero" {
  node         = var.node_id
  network_name = grid_network.hero_network.name
  name         = "hero_app"

  vms {
    name             = "hero"
    flist            = "https://hub.grid.tf/tf-official-vms/ubuntu-24.04-full.flist"
    cpu              = var.cpu
    memory           = var.memory
    entrypoint       = "/sbin/init"
    mycelium_ip_seed = random_bytes.mycelium_ip_seed.hex

    env_vars = {
      SSH_KEY = var.SSH_KEY != null ? var.SSH_KEY : (
        fileexists(pathexpand("~/.ssh/id_ed25519.pub")) ?
        file(pathexpand("~/.ssh/id_ed25519.pub")) :
        file(pathexpand("~/.ssh/id_rsa.pub"))
      )
      HERO_ROLE = "app"
    }

    publicip = true
  }
}

variable "node_id" {
  type        = number
  description = "Node ID for the VM"
}

variable "cpu" {
  type        = number
  default     = 2
  description = "CPU cores for the VM"
}

variable "memory" {
  type        = number
  default     = 4096
  description = "Memory in MB for the VM"
}

variable "SSH_KEY" {
  type        = string
  default     = null
  description = "SSH public key content (if null, will use ~/.ssh/id_ed25519.pub)"
}

output "vm_public_ip" {
  value = grid_deployment.hero.vms[0].computedip
}

output "vm_wireguard_ip" {
  value = grid_deployment.hero.vms[0].ip
}

output "vm_mycelium_ip" {
  value = grid_deployment.hero.vms[0].mycelium_ip
}

output "wg_config" {
  value     = grid_network.hero_network.access_wg_config
  sensitive = true
}

output "tfgrid_network" {
  value       = var.tfgrid_network
  description = "ThreeFold Grid network (main, test, dev)"
}