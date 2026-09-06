module "test" {
  source = "../../modules/debian-vm"

  vm_id = 200
  name  = "iac-test-01"

  node_name      = var.proxmox_node
  template_vm_id = var.template_vm_id
  datastore      = var.vm_datastore
  bridge         = var.vm_bridge

  cores  = 2
  memory = 2048
}

module "mgmt_01" {
  source = "../../modules/debian-vm"

  vm_id = 190
  name  = "mgmt-01"

  node_name      = var.proxmox_node
  template_vm_id = var.template_vm_id
  datastore      = var.vm_datastore
  bridge         = var.vm_bridge

  cores  = 2
  memory = 4096
}
