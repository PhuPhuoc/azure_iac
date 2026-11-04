variable "name_prefix" {
  description = "Prefix used to build the storage account name."
  type        = string
}

variable "suffix" {
  description = "Environment suffix used to build the storage account name."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group that owns the storage account."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "replication_type" {
  description = "Storage replication. LRS is enough for media that can be re-uploaded."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "replication_type must be one of LRS, ZRS, GRS, RAGRS, GZRS, RAGZRS."
  }
}

variable "container_name" {
  description = "Blob container that receives Strapi uploads."
  type        = string
  default     = "uploads"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])?$", var.container_name))
    error_message = "container_name must be 3-63 chars, lowercase alphanumeric or dashes."
  }
}

variable "sas_start" {
  description = "SAS validity start (RFC 3339). Keep it fixed: a relative value re-signs the URL on every apply."
  type        = string
  default     = "2026-01-01T00:00:00Z"
}

variable "sas_expiry" {
  description = "SAS validity end (RFC 3339). Rotate by changing this value and re-applying."
  type        = string
  default     = "2031-01-01T00:00:00Z"
}

variable "tags" {
  description = "Tags applied to the storage account."
  type        = map(string)
  default     = {}
}
