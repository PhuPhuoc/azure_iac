output "id" {
  description = "Container App resource ID."
  value       = azurerm_container_app.landing.id
}

output "name" {
  description = "Container App name, e.g. ca-cms-landing-abc123. Use it for az containerapp commands."
  value       = azurerm_container_app.landing.name
}

output "url" {
  description = "Stable public landing page URL."
  value       = local.landing_url
}

output "fqdn" {
  description = "FQDN currently assigned to ingress."
  value       = try(azurerm_container_app.landing.ingress[0].fqdn, null)
}

output "image" {
  description = "Fully qualified image reference deployed to the latest revision."
  value       = local.landing_image
}

output "latest_revision_name" {
  description = "Name of the latest revision, e.g. ca-cms-landing-abc123--<hash>."
  value       = azurerm_container_app.landing.latest_revision_name
}

output "latest_revision_fqdn" {
  description = "Revision-specific FQDN for smoke tests that must bypass the stable URL."
  value       = azurerm_container_app.landing.latest_revision_fqdn
}

output "outbound_ip_addresses" {
  description = "Egress IPs of the current revision. Diagnostics only: an allowlist here breaks the next revision."
  value       = azurerm_container_app.landing.outbound_ip_addresses
}
