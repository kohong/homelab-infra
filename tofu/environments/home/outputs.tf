output "vms" {
  description = "VM details for all managed VMs"

  value = {
    for name, vm in module.vm :
    name => {
      vm_id          = vm.vm_id
      ipv4_addresses = vm.ipv4_addresses
    }
  }
}
