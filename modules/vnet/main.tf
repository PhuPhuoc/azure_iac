locals {
  postgres_dns_zone_name = coalesce(
    var.postgres_dns_zone_name,
    "${var.name_prefix}-${var.suffix}.postgres.database.azure.com",
  )
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  tags = var.tags
}

# Azure reserves the first four and the last address of every subnet, so the
# prefixes below are sized for that headroom rather than for the raw count.
resource "azurerm_subnet" "aca" {
  name                 = "snet-aca-${var.suffix}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aca_subnet_prefix]

  # A Consumption workload profile environment may use a /27, and a
  # consumption-only environment needs a /23. /24 keeps either option open
  # without touching the neighbouring /28.
  delegation {
    name = "aca"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "postgres" {
  name                 = "snet-pg-${var.suffix}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.postgres_subnet_prefix]
  service_endpoints    = ["Microsoft.Storage"]

  # Delegation is a hard binding: the server cannot move to another subnet and
  # the subnet cannot host anything else.
  delegation {
    name = "postgres"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "bastion" {
  name                 = "snet-bastion-${var.suffix}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = local.postgres_dns_zone_name
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "pdnslink-pg-${var.suffix}"
  resource_group_name   = azurerm_private_dns_zone.postgres.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
}

# Outbound-only address for the Container Apps subnet: the platform no longer
# assigns the egress IP, so allow-listing goes through this one address.
# Domain name label is deliberately omitted, it would not reach the app.
resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-${var.name_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# StandardV2 is not supported for Container Apps environments.
resource "azurerm_nat_gateway" "nat" {
  name                = "nat-${var.name_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"

  tags = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

# One NAT gateway per subnet. Swapping or removing it is an in-place change on
# the subnet and does not recreate the Container Apps environment.
resource "azurerm_subnet_nat_gateway_association" "aca" {
  subnet_id      = azurerm_subnet.aca.id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}
