output "public_ip_address" {
  description = "Public address to SSH into. Null when the module is disabled."
  value       = azurerm_public_ip.bastion.ip_address
}

output "private_ip_address" {
  description = "Private address inside the bastion subnet."
  value       = azurerm_network_interface.bastion.private_ip_address
}

output "ssh_command" {
  description = "Ready-to-run SSH command."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.bastion.ip_address}"
}

output "pgweb_tunnel_command" {
  description = "Run on the workstation, then open http://127.0.0.1:8081. pgweb listens on the VM loopback only."
  value       = "ssh -N -L 8081:127.0.0.1:8081 ${var.admin_username}@${azurerm_public_ip.bastion.ip_address}"
}

output "vm_name" {
  description = "Virtual machine name."
  value       = azurerm_linux_virtual_machine.bastion.name
}
