locals {
  # Storage account names are globally unique, 3-24 chars, lowercase
  # alphanumeric. 2 + 11 (max name_prefix) + 5 + 6 (suffix) = 24.
  account_name = "st${var.name_prefix}media${var.suffix}"
}

resource "azurerm_storage_account" "main" {
  name                = local.account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  min_tls_version          = "TLS1_2"

  # Strapi stores the public blob URL on each asset and the frontend reads it
  # without a token, so anonymous read must stay allowed. Writes still require
  # the SAS below.
  allow_nested_items_to_be_public = true

  # Needed for the account-level SAS handed to the CMS.
  shared_access_key_enabled     = true
  public_network_access_enabled = true

  tags = var.tags
}

resource "azurerm_storage_container" "uploads" {
  name               = var.container_name
  storage_account_id = azurerm_storage_account.main.id

  # Public read, private write. Matches allow_nested_items_to_be_public above.
  container_access_type = "blob"
}

data "azurerm_storage_account_sas" "uploads" {
  connection_string = azurerm_storage_account.main.primary_connection_string
  https_only        = true
  signed_version    = "2022-11-02"

  # Fixed timestamps on purpose: a relative window (timeadd(timestamp(), ...))
  # re-signs and invalidates the URL on every apply.
  start  = var.sas_start
  expiry = var.sas_expiry

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  resource_types {
    service   = false
    container = true
    object    = true
  }

  permissions {
    read   = true
    add    = true
    create = true
    write  = true
    delete = true
    list   = true
  }
}
