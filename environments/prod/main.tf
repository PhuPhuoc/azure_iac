data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

locals {
  suffix    = "prod01"
  tags      = { project = "phungela", managed_by = "tf", env = "prod" }
  acr_repos = { cms = "cms", landing = "landing" }
}

module "vnet" {
  source = "../../modules/vnet"

  name_prefix         = var.name_prefix
  suffix              = local.suffix
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  tags                = local.tags
}

module "bastion" {
  source = "../../modules/bastion"

  count               = var.enable_bastion_vm ? 1 : 0
  name_prefix         = var.name_prefix
  suffix              = local.suffix
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  subnet_id           = module.vnet.bastion_subnet_id
  vm_size             = var.bastion_vm_size
  admin_username      = var.bastion_admin_username
  ssh_public_key      = var.bastion_ssh_public_key
  allowed_ssh_cidrs   = var.allowed_client_ips
  tags                = local.tags
}

module "postgres" {
  source = "../../modules/postgres"

  name_prefix         = var.name_prefix
  suffix              = local.suffix
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location

  postgres_version      = var.postgres_version
  sku_name              = var.postgres_sku_name
  storage_mb            = var.postgres_storage_mb
  backup_retention_days = var.postgres_backup_retention_days

  admin_login    = var.postgres_admin_login
  admin_password = var.postgres_admin_password
  database_name  = var.postgres_database_name

  tags = local.tags

  delegated_subnet_id           = module.vnet.postgres_subnet_id
  private_dns_zone_id           = module.vnet.postgres_dns_zone_id
  public_network_access_enabled = false

  depends_on = [module.vnet]
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

  name_prefix              = var.name_prefix
  suffix                   = local.suffix
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = var.location
  infrastructure_subnet_id = module.vnet.aca_subnet_id
  tags                     = local.tags
}

module "blob" {
  source = "../../modules/blob"

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

  database_host     = module.postgres.fqdn
  database_name     = module.postgres.database_name
  database_username = module.postgres.admin_login
  database_password = module.postgres.admin_password

  client_url               = var.cms_client_url
  strapi_stripe_secret_key = var.strapi_stripe_secret_key

  smtp_host             = var.cms_smtp_host
  smtp_port             = var.cms_smtp_port
  smtp_username         = var.cms_smtp_username
  smtp_password         = var.cms_smtp_password
  smtp_secure           = var.cms_smtp_secure
  smtp_default_from     = var.cms_smtp_default_from
  smtp_default_reply_to = var.cms_smtp_default_reply_to
  contact_inbox         = var.cms_contact_inbox

  blob_sas_url        = module.blob.sas_url
  blob_container_name = module.blob.container_name
  blob_cdn_url        = module.blob.container_url
}

# module "landing" {
#   source = "../../modules/landing"
#
#   name_prefix         = var.name_prefix
#   suffix              = local.suffix
#   resource_group_name = data.azurerm_resource_group.main.name
#   tags                = local.tags
#
#   container_app_environment_id   = module.aca.environment_id
#   app_environment_default_domain = module.aca.default_domain
#
#   acr_login_server         = module.acr.login_server
#   acr_admin_username       = module.acr.admin_username
#   acr_admin_password       = module.acr.admin_password
#   landing_image_repository = local.acr_repos.landing
#   landing_image_tag        = var.landing_image_tag
#
#   preview_secret = module.cms.preview_secret
# }

