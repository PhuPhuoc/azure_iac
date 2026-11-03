locals {
  cms_environment_name = "cae-${var.name_prefix}-${var.suffix}"
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.name_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = local.cms_environment_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  logs_destination           = "log-analytics"

  # An environment created without a workload profile can never gain one, and
  # only a workload profile environment can use a /27 subnet when it is moved
  # into a VNet later (/23 is required for consumption-only). Declaring the
  # Consumption profile now keeps that option open at no extra cost.
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = var.tags
}
