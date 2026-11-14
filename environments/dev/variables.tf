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

# Headless CMS (Container App)

variable "cms_image_tag" {
  description = "CMS image tag deployed from ACR. Pin a release tag for prod; latest follows the last push."
  type        = string
  default     = "latest"
}

variable "landing_image_tag" {
  description = "Landing page image tag deployed from ACR. Pin a release tag for prod; latest follows the last push."
  type        = string
  default     = "latest"
}

variable "cms_client_url" {
  description = "Public frontend URL used for admin preview origins and password-reset links. Null omits CLIENT_URL."
  type        = string
  default     = null

  validation {
    condition     = var.cms_client_url == null || can(regex("^https?://", var.cms_client_url))
    error_message = "cms_client_url must start with http:// or https://."
  }
}

variable "strapi_stripe_secret_key" {
  description = "Stripe secret key read by the order controller at boot. Prefer TF_VAR_strapi_stripe_secret_key; null omits the key."
  type        = string
  sensitive   = true
  default     = null
}

# CMS email (Strapi email plugin + form notifications). Setting cms_smtp_host
# enables the whole group; every other value below is then required.

variable "cms_smtp_host" {
  description = "SMTP host for the Strapi email plugin. Null leaves email unconfigured."
  type        = string
  default     = null

  validation {
    condition     = var.cms_smtp_host == null || var.cms_smtp_host != ""
    error_message = "cms_smtp_host must be null or a hostname, not an empty string."
  }
}

variable "cms_smtp_port" {
  description = "SMTP port. 587 pairs with cms_smtp_secure = false (STARTTLS), 465 with true."
  type        = number
  default     = 587
}

variable "cms_smtp_username" {
  description = "SMTP auth username. Required when cms_smtp_host is set."
  type        = string
  default     = null
}

variable "cms_smtp_password" {
  description = "SMTP auth password. Required when cms_smtp_host is set. Prefer TF_VAR_cms_smtp_password."
  type        = string
  sensitive   = true
  default     = null
}

variable "cms_smtp_secure" {
  description = "Implicit TLS for SMTP. False for STARTTLS on 587, true for 465."
  type        = bool
  default     = false
}

variable "cms_smtp_default_from" {
  description = "From address on outgoing mail. Required when cms_smtp_host is set."
  type        = string
  default     = null
}

variable "cms_smtp_default_reply_to" {
  description = "Reply-To address on outgoing mail. Required when cms_smtp_host is set."
  type        = string
  default     = null
}

variable "cms_contact_inbox" {
  description = "Recipient of form-submission notifications. Required when cms_smtp_host is set."
  type        = string
  default     = null
}
