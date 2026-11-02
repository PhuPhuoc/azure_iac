variable "name_prefix" {
  description = "Prefix used to build the registry name."
  type        = string
}

variable "suffix" {
  description = "Environment suffix used to build the registry name."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group that owns the registry."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "sku_name" {
  description = "Azure Container Registry SKU."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku_name)
    error_message = "sku_name must be one of Basic, Standard, Premium."
  }
}

variable "admin_enabled" {
  description = "Enable the registry admin account."
  type        = bool
  default     = true
}

variable "public_network_access_enabled" {
  description = "Allow access over the public endpoint."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the registry."
  type        = map(string)
  default     = {}
}
