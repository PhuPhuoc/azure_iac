output "postgres_fqdn" {
  description = "PostgreSQL Flexible Server hostname."
  value       = module.postgres.fqdn
}

output "postgres_database" {
  description = "Database name to run migrations against."
  value       = module.postgres.database_name
}

output "postgres_admin_login" {
  description = "Administrator login for migrations."
  value       = module.postgres.admin_login
}

output "postgres_admin_password" {
  description = "Effective PostgreSQL administrator password."
  value       = module.postgres.admin_password
  sensitive   = true
}

output "database_url" {
  description = "Full DSN for migrations and apps."
  value       = module.postgres.database_url
  sensitive   = true
}

output "acr_login_server" {
  description = "Registry host for image references."
  value       = module.acr.login_server
}

output "acr_name" {
  description = "ACR resource name for az acr commands."
  value       = module.acr.name
}

output "acr_repositories" {
  description = "Repository name per app."
  value       = local.acr_repos
}

output "acr_admin_username" {
  description = "Registry admin username."
  value       = module.acr.admin_username
}

output "acr_admin_password" {
  description = "Registry admin password."
  value       = module.acr.admin_password
  sensitive   = true
}

output "aca_environment_id" {
  description = "Container App Environment resource ID for container_app_environment_id."
  value       = module.aca.environment_id
}

output "aca_environment_name" {
  description = "Container App Environment name."
  value       = module.aca.environment_name
}

output "aca_default_domain" {
  description = "Environment default domain. App URLs are https://<app-name>.<default_domain>."
  value       = module.aca.default_domain
}

output "aca_log_analytics_workspace_id" {
  description = "Log Analytics workspace that receives Container Apps logs."
  value       = module.aca.log_analytics_workspace_id
}
