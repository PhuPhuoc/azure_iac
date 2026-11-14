locals {
  server_name    = "pg-${var.name_prefix}-${var.suffix}"
  admin_password = coalesce(var.admin_password, try(random_password.postgres[0].result, null))
}

resource "random_password" "postgres" {
  count = var.admin_password == null ? 1 : 0

  length  = 16
  upper   = true
  lower   = true
  numeric = true
  special = false
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
  public_network_access_enabled = var.public_network_access_enabled
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id

  tags = var.tags

  lifecycle {
    prevent_destroy = true

    # Azure assigns a primary zone at creation. Changing it later requires a
    # high-availability exchange, so keep the provider from nulling it out.
    ignore_changes = [zone]

    precondition {
      condition     = var.delegated_subnet_id == null || (var.private_dns_zone_id != null && var.public_network_access_enabled == false)
      error_message = "delegated_subnet_id requires private_dns_zone_id and public_network_access_enabled = false."
    }
  }
}

resource "azurerm_postgresql_flexible_server_database" "cms" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  lifecycle {
    prevent_destroy = true
  }
}

# One rule per developer workstation IP so migrations can run locally.
# Azure PostgreSQL firewall rules are IPv4 only.
resource "azurerm_postgresql_flexible_server_firewall_rule" "clients" {
  for_each = toset(var.public_network_access_enabled ? var.allowed_client_ips : [])

  name             = "allow-${replace(each.value, ".", "-")}"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = each.value
  end_ip_address   = each.value
}

# Azure treats 0.0.0.0/0.0.0.0 as "allow public access from any Azure service".
# Only useful while the server still has a public endpoint; VNet integration
# makes it redundant because the Container Apps subnet reaches the server
# over the delegated subnet.
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  count = var.public_network_access_enabled && var.allow_azure_services ? 1 : 0

  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
