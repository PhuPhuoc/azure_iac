terraform {
  required_version = ">= 1.17"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # The deploying principal is Contributor on the resource group only and
  # cannot call Microsoft.*/register, so resource namespaces must already be
  # registered before applying.
  resource_provider_registrations = "none"
}
