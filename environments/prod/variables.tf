# Global
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
  default     = "rg-cms-prod"
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
  default     = 35
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
  description = "IPv4 workstation addresses allowed to SSH to the bastion VM."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ip in var.allowed_client_ips : can(cidrhost("${ip}/32", 0))])
    error_message = "allowed_client_ips must contain plain IPv4 addresses."
  }
}

# Bastion
variable "enable_bastion_vm" {
  description = "Create the bastion VM used to reach the private PostgreSQL server."
  type        = bool
  default     = false
}

variable "bastion_vm_size" {
  description = "Azure VM size for the bastion."
  # SouthAfricaNorth KHÔNG có B-series v1 (B1s/B1ms/B2s không nằm trong
  # `az vm list-skus -l southafricanorth`, 2026-11-13). B2s_v2 tồn tại nhưng
  # quota sub cho standardBsv2Family = 0 và quyền xin increase cần Owner
  # (AuthorizationFailed 2026-11-13) ⇒ D2_v2: size rẻ nhất có quota sẵn
  # (standardDSv2Family = 10), đủ cho usage on-demand bật-tắt theo phiên
  # migration. Đổi lại B2s_v2 ($0.109/h vs $0.153/h) khi quota Bsv2 được duyệt.
  type    = string
  default = "Standard_D2_v2"
}

variable "bastion_admin_username" {
  description = "Admin username for the bastion VM."
  type        = string
  default     = "azureuser"
}

variable "bastion_ssh_public_key" {
  description = "OpenSSH public key for the bastion VM. Required when enable_bastion_vm is true; pass via TF_VAR_bastion_ssh_public_key."
  type        = string
  default     = ""
  nullable    = false

  # non-empty KHÔNG check được ở đây vì phụ thuộc enable_bastion_vm (validation không
  # cross-reference biến khác) → modules/bastion/ssh_public_key từ chối rỗng, và
  # validation đó chỉ chạy khi count = 1, tức là khi bastion được bật.
  validation {
    condition     = var.bastion_ssh_public_key == "" || can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ", var.bastion_ssh_public_key))
    error_message = "bastion_ssh_public_key must be an OpenSSH public key (ssh-rsa, ssh-ed25519, or ecdsa-sha2-*)."
  }
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
