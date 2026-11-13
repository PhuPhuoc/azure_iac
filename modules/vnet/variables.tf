variable "name_prefix" {
  description = "Prefix used to build resource names."
  type        = string
}

variable "suffix" {
  description = "Environment suffix used to build resource names."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group that owns the network."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.60.0.0/16"]
}

variable "aca_subnet_prefix" {
  description = "CIDR for the Container Apps environment subnet."
  type        = string
  default     = "10.60.0.0/24"
}

variable "postgres_subnet_prefix" {
  description = "CIDR for the PostgreSQL delegated subnet."
  type        = string
  default     = "10.60.1.0/28"
}

variable "bastion_subnet_prefix" {
  description = "CIDR for the bastion subnet."
  type        = string
  default     = "10.60.2.0/27"
}

variable "postgres_dns_zone_name" {
  description = "Private DNS zone name for PostgreSQL. Null derives <name_prefix>-<suffix>.postgres.database.azure.com."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource in the module."
  type        = map(string)
  default     = {}
}
