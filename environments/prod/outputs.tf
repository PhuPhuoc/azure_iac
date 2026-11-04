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

output "headless_cms_name" {
  description = "Container App name for az containerapp commands."
  value       = module.headless_cms.name
}

output "headless_cms_url" {
  description = "Public CMS URL. Unreachable while cms_paused is true."
  value       = module.headless_cms.url
}

output "headless_cms_fqdn" {
  description = "FQDN currently assigned to CMS ingress."
  value       = module.headless_cms.fqdn
}

output "headless_cms_image" {
  description = "Image reference deployed to the CMS."
  value       = module.headless_cms.image
}

output "headless_cms_outbound_ip_addresses" {
  description = "CMS egress IPs for the current revision. Diagnostics only."
  value       = module.headless_cms.outbound_ip_addresses
}

output "headless_cms_latest_revision_name" {
  description = "Latest CMS revision name."
  value       = module.headless_cms.latest_revision_name
}

output "headless_cms_preview_secret" {
  description = "Shared PREVIEW_SECRET for the frontend draft-mode route."
  value       = module.headless_cms.preview_secret
  sensitive   = true
}

output "landing_name" {
  description = "Container App name for az containerapp commands."
  value       = module.landing.name
}

output "landing_url" {
  description = "Public landing page URL."
  value       = module.landing.url
}

output "landing_fqdn" {
  description = "FQDN currently assigned to landing ingress."
  value       = module.landing.fqdn
}

output "landing_image" {
  description = "Image reference deployed to the landing page."
  value       = module.landing.image
}

output "blob_storage_account_name" {
  description = "Storage account that holds CMS uploads."
  value       = module.blob.storage_account_name
}

output "blob_container_name" {
  description = "AZURE_STORAGE_CONTAINER_NAME for local upload testing."
  value       = module.blob.container_name
}

output "blob_cdn_url" {
  description = "AZURE_STORAGE_CDN_URL for local upload testing. Blob endpoint until a CDN exists."
  value       = module.blob.container_url
}

output "blob_sas_url" {
  description = "AZURE_STORAGE_SAS_URL for local upload testing."
  value       = module.blob.sas_url
  sensitive   = true
}
