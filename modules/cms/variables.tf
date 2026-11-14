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

variable "revision_health_gate" {
  description = "After apply, poll the new revision and fail the apply unless it reports Healthy. Requires the az CLI logged into the target subscription on the machine running Terraform."
  type        = bool
  default     = true
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

# Blob storage
variable "blob_sas_url" {
  description = "SAS URL to a blob storage container. Used for Strapi media uploads."
  type        = string
  sensitive   = true
}

variable "blob_container_name" {
  description = "Name of the blob storage container. Used for Strapi media uploads."
  type        = string
  default     = "uploads"
}

variable "blob_cdn_url" {
  description = "Public base URL served to end users for files in the container (blob container URL until a CDN exists)."
  type        = string
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

# Email (Strapi email plugin + form notifications)

variable "smtp_host" {
  description = "SMTP host. Null or empty omits every SMTP/CONTACT_INBOX env var, leaving the app's built-in defaults."
  type        = string
  default     = null
}

variable "smtp_port" {
  description = "SMTP port. 587 pairs with smtp_secure = false (STARTTLS), 465 with true."
  type        = number
  default     = 587
}

variable "smtp_username" {
  description = "SMTP auth username. Required when smtp_host is set."
  type        = string
  default     = null
}

variable "smtp_password" {
  description = "SMTP auth password, delivered to the app as a Container App secret. Required when smtp_host is set."
  type        = string
  sensitive   = true
  default     = null
}

variable "smtp_secure" {
  description = "Implicit TLS for the SMTP connection (SMTP_SECURE). False for STARTTLS on 587, true for 465."
  type        = bool
  default     = false
}

variable "smtp_default_from" {
  description = "From address on outgoing mail (SMTP_DEFAULT_FROM). Required when smtp_host is set."
  type        = string
  default     = null
}

variable "smtp_default_reply_to" {
  description = "Reply-To address on outgoing mail (SMTP_DEFAULT_REPLY_TO). Required when smtp_host is set."
  type        = string
  default     = null
}

variable "contact_inbox" {
  description = "Recipient of form-submission notifications (CONTACT_INBOX). Required when smtp_host is set; the app falls back to ADMIN_EMAIL only when this is unset."
  type        = string
  default     = null
}
