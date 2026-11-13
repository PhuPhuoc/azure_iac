variable "name_prefix" {
  description = "Prefix used to build resource names."
  type        = string
}

variable "suffix" {
  description = "Environment suffix used to build resource names."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group that owns the bastion resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "subnet_id" {
  description = "Subnet the network interface joins."
  type        = string
}

variable "vm_size" {
  description = "Azure VM size for the bastion."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username on the VM."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "OpenSSH public key allowed to log in."
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.ssh_public_key) != ""
    error_message = "ssh_public_key must not be empty or whitespace only."
  }

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key (ssh-rsa, ssh-ed25519, or ecdsa-sha2-*)."
  }
}

variable "allowed_ssh_cidrs" {
  description = "Plain IPv4 addresses allowed to reach port 22."
  type        = list(string)

  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0 && alltrue([for ip in var.allowed_ssh_cidrs : can(cidrhost("${ip}/32", 0))])
    error_message = "allowed_ssh_cidrs must contain at least one plain IPv4 address."
  }

  validation {
    condition     = !contains(var.allowed_ssh_cidrs, "0.0.0.0/0")
    error_message = "Không được mở SSH cho 0.0.0.0/0."
  }
}

variable "tags" {
  description = "Tags applied to every resource in the module."
  type        = map(string)
  default     = {}
}
