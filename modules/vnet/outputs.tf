output "vnet_id" {
  description = "Virtual network ID."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Virtual network name."
  value       = azurerm_virtual_network.this.name
}

output "aca_subnet_id" {
  description = "Subnet joined by the Container Apps environment."
  value       = azurerm_subnet.aca.id
}

output "postgres_subnet_id" {
  description = "Delegated subnet used by PostgreSQL VNet integration."
  value       = azurerm_subnet.postgres.id
}

output "bastion_subnet_id" {
  description = "Subnet that holds the bastion VM."
  value       = azurerm_subnet.bastion.id
}

output "postgres_dns_zone_id" {
  description = "Private DNS zone linked into the VNet for PostgreSQL."
  value       = azurerm_private_dns_zone.postgres.id
}

output "postgres_dns_zone_name" {
  description = "Private DNS zone name, also the PostgreSQL private suffix."
  value       = azurerm_private_dns_zone.postgres.name
}

output "nat_gateway_id" {
  description = "NAT gateway attached to the Container Apps subnet."
  value       = azurerm_nat_gateway.nat.id
}

output "nat_public_ip" {
  description = "Static egress address used by Container Apps outbound traffic."
  value       = azurerm_public_ip.nat.ip_address
}
