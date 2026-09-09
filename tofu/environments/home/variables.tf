variable "proxmox_node" {
  description = "Proxmox node on which VMs will be created"
  type        = string
  default     = "pve"
}

variable "template_vm_id" {
  description = "VM ID of the Debian golden template"
  type        = number
  default     = 9000
}

variable "vm_datastore" {
  description = "Default Proxmox datastore for VM disks"
  type        = string
  default     = "fast-vm"
}

variable "vm_bridge" {
  description = "Default Proxmox bridge for VMs"
  type        = string
  default     = "vmbr0"
}

variable "vms" {
  type = map(object({
    vm_id          = number
    cores          = number
    memory         = number
    disk_size      = number
    ansible_groups = optional(list(string), [])
  }))

  default = {
    mgmt-01 = {
      vm_id          = 190
      cores          = 2
      memory         = 4096
      disk_size      = 15
      ansible_groups = ["management"]
    }

    ai-gateway-01 = {
      vm_id          = 201
      cores          = 4
      memory         = 8192
      disk_size      = 100
      ansible_groups = ["ai_gateway"]
    }

    hermes-01 = {
      vm_id          = 202
      cores          = 4
      memory         = 8192
      disk_size      = 100
      ansible_groups = ["agents"]
    }

  }
}
