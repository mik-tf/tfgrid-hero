terraform {
  required_providers {
    grid = {
      source  = "threefoldtech/grid"
    }
  }
}

provider "grid" {
  mnemonics = var.mnemonics
  network   = var.tfgrid_network
  relay_url = var.tfgrid_network == "main" ? "wss://relay.grid.tf" : "wss://relay.test.grid.tf"
}

variable "mnemonics" {
  type        = string
  description = "The mnemonics of the account"
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

# Hero VM (herolib backend + ui_colab frontend + redis + nginx)
resource "grid_deployment" "hero" {
  node = var.node_id
  name = "hero-app"

  vms {
    name       = "hero"
    flist      = "https://hub.grid.tf/tf-official-vms/ubuntu-24.04-full.flist"
    cpu        = var.cpu
    memory     = var.memory
    entrypoint = "/sbin/init"

    env_vars = {
      SSH_KEY = var.ssh_key
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

variable "ssh_key" {
  type        = string
  description = "SSH public key for access"
}

output "vm_public_ip" {
  value = grid_deployment.hero.vms[0].computedip
}

output "vm_wireguard_ip" {
  value = grid_deployment.hero.vms[0].ip
}

output "vm_mycelium_ip" {
  value = grid_deployment.hero.vms[0].ygg_ip
}

output "wg_config" {
  value = grid_deployment.hero.vms[0].wireguard_config
  sensitive = true
}

output "tfgrid_network" {
  value       = var.tfgrid_network
  description = "ThreeFold Grid network (main, test, dev)"
}