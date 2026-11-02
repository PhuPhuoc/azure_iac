output "id" {
  description = "Registry resource ID."
  value       = azurerm_container_registry.main.id
}

output "name" {
  description = "Registry resource name."
  value       = azurerm_container_registry.main.name
}

output "login_server" {
  description = "Registry host for image references."
  value       = azurerm_container_registry.main.login_server
}

output "admin_username" {
  description = "Registry admin username."
  value       = azurerm_container_registry.main.admin_username
}

output "admin_password" {
  description = "Registry admin password."
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}
