terraform {
  # Same state storage as prod; each environment uses a different key.
  backend "azurerm" {
    subscription_id      = "cb0f4bbe-bcbe-4466-a105-edb4bf1b21a5"
    resource_group_name  = "rg-cms-prod"
    storage_account_name = "stcmsxs8ytf"
    container_name       = "tfstate"
    key                  = "staging.terraform.tfstate"
  }
}
