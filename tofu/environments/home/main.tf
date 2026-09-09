module "vm" {
  source = "../../modules/debian-vm"

  for_each = var.vms

  name  = each.key
  vm_id = each.value.vm_id

  cores     = each.value.cores
  memory    = each.value.memory
  disk_size = each.value.disk_size

  node_name      = var.proxmox_node
  template_vm_id = var.template_vm_id
  datastore      = var.vm_datastore
  bridge         = var.vm_bridge

  ssh_public_keys = local.ssh_public_keys
}
