output "server_id" {
  description = "PostgreSQL Flexible Server resource ID."
  value       = azurerm_postgresql_flexible_server.main.id
}

output "server_name" {
  description = "PostgreSQL Flexible Server name."
  value       = azurerm_postgresql_flexible_server.main.name
}

output "fqdn" {
  description = "PostgreSQL server hostname."
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "database_name" {
  description = "Application database name."
  value       = azurerm_postgresql_flexible_server_database.cms.name
}

output "admin_login" {
  description = "Administrator login."
  value       = var.admin_login
}

output "admin_password" {
  description = "Effective administrator password."
  value       = local.admin_password
  sensitive   = true
}

output "database_url" {
  description = "Full DSN for migrations and apps."
  value = format(
    "postgresql://%s:%s@%s:5432/%s?sslmode=require",
    var.admin_login,
    urlencode(local.admin_password),
    azurerm_postgresql_flexible_server.main.fqdn,
    azurerm_postgresql_flexible_server_database.cms.name,
  )
  sensitive = true
}
