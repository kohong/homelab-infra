output "test_vm_id" {
  description = "VM ID of the test Debian VM"
  value       = module.test.vm_id
}

output "test_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent"
  value       = module.test.ipv4_addresses
}
