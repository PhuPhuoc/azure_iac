output "storage_account_id" {
  description = "Storage account resource ID."
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Storage account name, e.g. stcmsmediaxs8ytf."
  value       = azurerm_storage_account.main.name
}

output "blob_endpoint" {
  description = "Account blob endpoint, e.g. https://<account>.blob.core.windows.net."
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "container_name" {
  description = "Container name. Maps to AZURE_STORAGE_CONTAINER_NAME."
  value       = azurerm_storage_container.uploads.name
}

output "container_url" {
  description = "Public read base for the container, no token. Used as AZURE_STORAGE_CDN_URL until a real CDN is added."
  value       = "${azurerm_storage_account.main.primary_blob_endpoint}${azurerm_storage_container.uploads.name}"
}

output "sas_url" {
  description = "Container URL with account SAS (read/write/delete on objects). Maps to AZURE_STORAGE_SAS_URL."
  value       = "${azurerm_storage_account.main.primary_blob_endpoint}${azurerm_storage_container.uploads.name}?${data.azurerm_storage_account_sas.uploads.sas}"
  sensitive   = true
}
