variable "name_prefix" {
  description = "Prefix used to build the server name."
  type        = string
}

variable "suffix" {
  description = "Environment suffix used to build the server name."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group that owns the server."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "postgres_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "sku_name" {
  description = "PostgreSQL Flexible Server SKU."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage in MB."
  type        = number
  default     = 32768
}

variable "backup_retention_days" {
  description = "Backup retention in days."
  type        = number
  default     = 7
}

variable "admin_login" {
  description = "Administrator login."
  type        = string
  default     = "cmsadmin"
}

variable "admin_password" {
  description = "Administrator password. Null generates one and stores it in state."
  type        = string
  sensitive   = true
  default     = null
}

variable "database_name" {
  description = "Application database name."
  type        = string
  default     = "cms"
}

variable "allowed_client_ips" {
  description = "IPv4 addresses allowed to reach PostgreSQL (workstation IPs that run migrations)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ip in var.allowed_client_ips : can(cidrhost("${ip}/32", 0))])
    error_message = "allowed_client_ips must contain plain IPv4 addresses."
  }
}

variable "allow_azure_services" {
  description = "Enable the 0.0.0.0 firewall rule for Azure Container Apps egress."
  type        = bool
  default     = false
}

variable "delegated_subnet_id" {
  description = "Subnet ID for VNet integration. Null keeps public access."
  type        = string
  default     = null
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID required when delegated_subnet_id is set."
  type        = string
  default     = null
}

variable "public_network_access_enabled" {
  description = "Whether the server has a public endpoint. Must be false with delegated_subnet_id."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the server."
  type        = map(string)
  default     = {}
}
