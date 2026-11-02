data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  suffix    = random_string.suffix.result
  tags      = { project = "phungela-cms", managed_by = "tf" }
  acr_repos = { cms = "cms", landing = "landing" }
}

module "postgres" {
  source = "../../modules/postgres"

  name_prefix           = var.name_prefix
  suffix                = local.suffix
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = var.location
  postgres_version      = var.postgres_version
  sku_name              = var.postgres_sku_name
  storage_mb            = var.postgres_storage_mb
  backup_retention_days = var.postgres_backup_retention_days
  admin_login           = var.postgres_admin_login
  admin_password        = var.postgres_admin_password
  database_name         = var.postgres_database_name
  allowed_client_ips    = var.allowed_client_ips
  allow_azure_services  = var.postgres_allow_azure_services
  tags                  = local.tags
}

module "acr" {
  source = "../../modules/acr"

  name_prefix                   = var.name_prefix
  suffix                        = local.suffix
  resource_group_name           = data.azurerm_resource_group.main.name
  location                      = var.location
  sku_name                      = var.acr_sku_name
  admin_enabled                 = var.acr_admin_enabled
  public_network_access_enabled = true
  tags                          = local.tags
}
