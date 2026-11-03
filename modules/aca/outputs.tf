output "environment_id" {
  description = "Container App Environment resource ID for container_app_environment_id."
  value       = azurerm_container_app_environment.main.id
}

output "environment_name" {
  description = "Container App Environment name."
  value       = azurerm_container_app_environment.main.name
}

output "default_domain" {
  description = "Environment default domain. App URLs are https://<app-name>.<default_domain>."
  value       = azurerm_container_app_environment.main.default_domain
}

output "static_ip_address" {
  description = "Environment static IP. Null unless the environment uses an internal load balancer."
  value       = azurerm_container_app_environment.main.static_ip_address
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace that receives Container Apps logs."
  value       = azurerm_log_analytics_workspace.main.id
}
