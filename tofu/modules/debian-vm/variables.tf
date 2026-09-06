variable "name" {
  type = string
}

variable "vm_id" {
  type = number
}

variable "node_name" {
  type    = string
  default = "pve"
}

variable "template_vm_id" {
  type    = number
  default = 9000
}

variable "datastore" {
  type    = string
  default = "fast-vm"
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
}

variable "bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "ssh_public_keys" {
  description = "SSH public keys to install for the VM user"
  type        = list(string)
  default     = []
}
