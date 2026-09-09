resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  vm_id     = var.vm_id
  node_name = var.node_name

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.datastore
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  network_device {
    bridge = var.bridge
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = var.disk_size
  }

  initialization {
    datastore_id = var.datastore

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "homelab"
      keys     = var.ssh_public_keys
    }
  }
}
