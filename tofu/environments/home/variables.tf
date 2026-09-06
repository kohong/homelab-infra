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
    vm_id  = number
    cores  = number
    memory = number
  }))

  default = {
    mgmt-01 = {
      vm_id  = 190
      cores  = 2
      memory = 4096
    }

  }
}
