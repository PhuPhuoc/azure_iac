moved {
  from = azurerm_postgresql_flexible_server.main
  to   = module.postgres.azurerm_postgresql_flexible_server.main
}

moved {
  from = azurerm_postgresql_flexible_server_database.cms
  to   = module.postgres.azurerm_postgresql_flexible_server_database.cms
}

moved {
  from = azurerm_postgresql_flexible_server_firewall_rule.clients
  to   = module.postgres.azurerm_postgresql_flexible_server_firewall_rule.clients
}

moved {
  from = azurerm_postgresql_flexible_server_firewall_rule.azure_services
  to   = module.postgres.azurerm_postgresql_flexible_server_firewall_rule.azure_services
}

moved {
  from = azurerm_container_registry.main
  to   = module.acr.azurerm_container_registry.main
}
