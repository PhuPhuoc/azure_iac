output "id" {
  description = "Container App resource ID."
  value       = azurerm_container_app.headless_cms.id
}

output "name" {
  description = "Container App name, e.g. ca-cms-abc123. Use it for az containerapp commands."
  value       = azurerm_container_app.headless_cms.name
}

output "url" {
  description = "Stable public CMS URL."
  value       = local.cms_url
}

output "fqdn" {
  description = "FQDN currently assigned to ingress. Null when the app has no ingress."
  value       = try(azurerm_container_app.headless_cms.ingress[0].fqdn, null)
}

output "image" {
  description = "Fully qualified image reference deployed to the latest revision."
  value       = local.cms_image
}

output "latest_revision_name" {
  description = "Name of the latest revision, e.g. ca-cms-abc123--<hash>."
  value       = azurerm_container_app.headless_cms.latest_revision_name
}

output "latest_revision_fqdn" {
  description = "Revision-specific FQDN for smoke tests that must bypass the stable URL."
  value       = azurerm_container_app.headless_cms.latest_revision_fqdn
}

output "outbound_ip_addresses" {
  description = "Egress IPs of the current revision. Diagnostics only: an allowlist here breaks the next revision."
  value       = azurerm_container_app.headless_cms.outbound_ip_addresses
}

output "preview_secret" {
  description = "Shared PREVIEW_SECRET. The frontend draft-mode route must use the same value."
  value       = random_password.strapi_preview_secret.result
  sensitive   = true
}
