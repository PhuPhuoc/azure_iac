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

module "aca" {
  source = "../../modules/aca"

  name_prefix         = var.name_prefix
  suffix              = local.suffix
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  tags                = local.tags
}

module "cms" {
  source = "../../modules/cms"

  name_prefix         = var.name_prefix
  suffix              = local.suffix
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.tags

  container_app_environment_id   = module.aca.environment_id
  app_environment_default_domain = module.aca.default_domain

  acr_login_server     = module.acr.login_server
  acr_admin_username   = module.acr.admin_username
  acr_admin_password   = module.acr.admin_password
  cms_image_repository = local.acr_repos.cms
  cms_image_tag        = var.cms_image_tag
  cms_paused           = var.cms_paused

  database_host     = module.postgres.fqdn
  database_name     = module.postgres.database_name
  database_username = module.postgres.admin_login
  database_password = module.postgres.admin_password

  client_url               = var.cms_client_url
  strapi_stripe_secret_key = var.strapi_stripe_secret_key

  blob_sas_url        = module.blob.sas_url
  blob_container_name = module.blob.container_name
  blob_cdn_url        = module.blob.container_url
}

# Public landing page. PREVIEW_SECRET is the CMS-generated value, so the
# draft-mode redirect stays in sync without a second source of truth.
module "landing" {
  source = "../../modules/landing"

  name_prefix         = var.name_prefix
  suffix              = local.suffix
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.tags

  container_app_environment_id   = module.aca.environment_id
  app_environment_default_domain = module.aca.default_domain

  acr_login_server         = module.acr.login_server
  acr_admin_username       = module.acr.admin_username
  acr_admin_password       = module.acr.admin_password
  landing_image_repository = local.acr_repos.landing
  landing_image_tag        = var.landing_image_tag

  preview_secret = module.cms.preview_secret
}

# Media storage. Its SAS/URL feed the CMS upload plugin; outputs also stay
# exposed for local Strapi testing against the same account.
module "blob" {
  source = "../../modules/blob"

  name_prefix         = var.name_prefix
  suffix              = local.suffix
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  tags                = local.tags
}
