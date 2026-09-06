output "ansible_inventory" {
  description = "VM information consumed by Ansible"

  value = {
    for name, vm in module.vm :
    name => {
      vm_id          = vm.vm_id
      ipv4_addresses = vm.ipv4_addresses
      groups          = var.vms[name].ansible_groups
    }
  }
}
