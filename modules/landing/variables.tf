variable "name_prefix" {
  description = "Prefix used to build the container app name."
  type        = string
}

variable "suffix" {
  description = "Environment suffix used to build the container app name."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group that owns the container app."
  type        = string
}

variable "tags" {
  description = "Tags applied to the container app."
  type        = map(string)
  default     = {}
}

# Compute

variable "landing_image_tag" {
  description = "Image tag to deploy. Pin a release tag or digest for prod."
  type        = string
  default     = "latest"
}

variable "landing_image_repository" {
  description = "ACR repository name that holds the landing page image."
  type        = string
  default     = "landing"
}

variable "workload_profile_name" {
  description = "Workload profile used by the app. Consumption is the default profile of a Consumption-only environment."
  type        = string
  default     = "Consumption"
}

variable "container_app_environment_id" {
  description = "Container App Environment resource ID."
  type        = string
}

variable "app_environment_default_domain" {
  description = "Container App Environment default domain, used to build the public URL."
  type        = string
}

# Registry access

variable "acr_login_server" {
  description = "Registry host for the image reference, e.g. acrcmsxxxxxx.azurecr.io."
  type        = string
}

variable "acr_admin_username" {
  description = "Registry admin username. Used because AcrPull role assignments are unavailable."
  type        = string
}

variable "acr_admin_password" {
  description = "Registry admin password. Requires admin_enabled on the registry."
  type        = string
  sensitive   = true
}

# Application

variable "preview_secret" {
  description = "Shared draft-mode secret. Must equal the CMS PREVIEW_SECRET, otherwise /api/preview answers 401."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.preview_secret) > 0
    error_message = "preview_secret must not be empty; it has to match the CMS value."
  }
}

variable "website_url" {
  description = "Public site URL used by app/robots.ts and app/sitemap.ts. Null uses the app's own ACA URL."
  type        = string
  default     = null

  validation {
    condition     = var.website_url == null || can(regex("^https?://", var.website_url))
    error_message = "website_url must start with http:// or https://."
  }
}
