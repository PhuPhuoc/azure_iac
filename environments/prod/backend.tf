terraform {
  # Azure Blob Storage is the equivalent of S3 for Terraform state. State
  # locking is handled by a blob lease.
  #
  # The storage account/container are bootstrapped once with the az CLI (see
  # README) and are intentionally not managed by this configuration.
  #
  # Authentication uses ARM_ACCESS_KEY because the principal cannot create
  # role assignments. If you later grant Storage Blob Data Contributor, set
  # use_azuread_auth = true and remove ARM_ACCESS_KEY.
  backend "azurerm" {
    subscription_id      = "cb0f4bbe-bcbe-4466-a105-edb4bf1b21a5"
    resource_group_name  = "rg-cms-prod"
    storage_account_name = "stcmsxs8ytf"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}
