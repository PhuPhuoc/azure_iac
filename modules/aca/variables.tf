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

variable "tags" {
  description = "Tags applied to the registry."
  type        = map(string)
  default     = {}
}
