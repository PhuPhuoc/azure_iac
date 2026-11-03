variable "subscription_id" {
  description = "Azure subscription id. Null inherits the az CLI default."
  type        = string
  default     = null
}

variable "tenant_id" {
  description = "Azure AD tenant id. Null inherits the az CLI default."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region for every resource."
  type        = string
  default     = "southafricanorth"
}

variable "resource_group_name" {
  description = "Existing resource group that owns all resources."
  type        = string
  default     = "rg-cms-dev"
}

variable "name_prefix" {
  description = "Prefix for generated resource names."
  type        = string
  default     = "cms"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,10}$", var.name_prefix))
    error_message = "name_prefix must be 2-11 chars, lowercase alphanumeric, starting with a letter."
  }
}

# PostgreSQL

variable "postgres_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "postgres_sku_name" {
  description = "PostgreSQL Flexible Server SKU."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage in MB."
  type        = number
  default     = 32768
}

variable "postgres_backup_retention_days" {
  description = "PostgreSQL backup retention in days."
  type        = number
  default     = 7
}

variable "postgres_admin_login" {
  description = "PostgreSQL administrator login."
  type        = string
  default     = "cmsadmin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL administrator password. Set this for prod to avoid rotating an existing password."
  type        = string
  sensitive   = true
  default     = null
}

variable "postgres_database_name" {
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

variable "postgres_allow_azure_services" {
  description = "Enable the 0.0.0.0 firewall rule for Azure services. Required once a Container App in this environment connects to PostgreSQL."
  type        = bool
  default     = false
}

# ACR

variable "acr_sku_name" {
  description = "Azure Container Registry SKU."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku_name)
    error_message = "acr_sku_name must be one of Basic, Standard, Premium."
  }
}

variable "acr_admin_enabled" {
  description = "Enable the registry admin account."
  type        = bool
  default     = true
}
