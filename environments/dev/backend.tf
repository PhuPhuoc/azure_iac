terraform {
  # Same state storage as prod; each environment uses a different key.
  # subscription_id is not pinned here: export ARM_SUBSCRIPTION_ID (or set it
  # in the environment that runs terraform) so no account id lands in the repo.
  backend "azurerm" {
    resource_group_name  = "rg-cms-prod"
    storage_account_name = "stcmsxs8ytf"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
