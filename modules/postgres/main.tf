locals {
  server_name    = "pg-${var.name_prefix}-${var.suffix}"
  admin_password = coalesce(var.admin_password, try(random_password.postgres[0].result, null))
}

resource "random_password" "postgres" {
  count = var.admin_password == null ? 1 : 0

  length           = 24
  special          = true
  override_special = "-_"
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                = local.server_name
  resource_group_name = var.resource_group_name
  location            = var.location

  version                       = var.postgres_version
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  backup_retention_days         = var.backup_retention_days
  administrator_login           = var.admin_login
  administrator_password        = local.admin_password
  public_network_access_enabled = true

  tags = var.tags

  lifecycle {
    # Azure assigns a primary zone at creation. Changing it later requires a
    # high-availability exchange, so keep the provider from nulling it out.
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "cms" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# One rule per developer workstation IP so migrations can run locally.
# Azure PostgreSQL firewall rules are IPv4 only.
resource "azurerm_postgresql_flexible_server_firewall_rule" "clients" {
  for_each = toset(var.allowed_client_ips)

  name             = "allow-${replace(each.value, ".", "-")}"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = each.value
  end_ip_address   = each.value
}

# Azure treats 0.0.0.0/0.0.0.0 as "allow public access from any Azure service".
# It is the documented option for Container Apps egress when the environment
# has no static outbound IP (VNet + NAT gateway).
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  count = var.allow_azure_services ? 1 : 0

  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
