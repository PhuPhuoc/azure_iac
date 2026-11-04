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

variable "cms_image_tag" {
  description = "Image tag to deploy. Pin a release tag or digest for prod."
  type        = string
}

variable "cms_image_repository" {
  description = "ACR repository name that holds the CMS image."
  type        = string
  default     = "cms"
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

variable "cms_paused" {
  description = "Scale the app to zero and disable ingress. The database and registry stay untouched."
  type        = bool
  default     = false
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

# Database

variable "database_host" {
  description = "PostgreSQL hostname."
  type        = string
}

variable "database_port" {
  description = "PostgreSQL port."
  type        = string
  default     = "5432"
}

variable "database_name" {
  description = "Application database name."
  type        = string
}

variable "database_username" {
  description = "Database user."
  type        = string
}

variable "database_password" {
  description = "Database password."
  type        = string
  sensitive   = true
}

# Application

variable "client_url" {
  description = "Public frontend URL. Sets CLIENT_URL for admin preview origins and password-reset links. Omitted when null."
  type        = string
  default     = null
}

variable "strapi_stripe_secret_key" {
  description = "Stripe secret key read by the order controller at boot. Omitted when null."
  type        = string
  sensitive   = true
  default     = null
}
