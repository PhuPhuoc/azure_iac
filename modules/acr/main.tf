resource "azurerm_container_registry" "main" {
  name                = "acr${var.name_prefix}${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku           = var.sku_name
  admin_enabled = var.admin_enabled

  # The registry is consumed over its public endpoint. Do not disable without
  # a private endpoint and the corresponding DNS/network wiring.
  public_network_access_enabled = var.public_network_access_enabled

  tags = var.tags
}
