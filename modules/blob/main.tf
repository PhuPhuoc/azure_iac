locals {
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

  allow_nested_items_to_be_public = true

  # Needed for the account-level SAS handed to the CMS.
  shared_access_key_enabled     = true
  public_network_access_enabled = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "uploads" {
  name               = var.container_name
  storage_account_id = azurerm_storage_account.main.id

  # Public read, private write. Matches allow_nested_items_to_be_public above.
  container_access_type = "blob"

  lifecycle {
    prevent_destroy = true
  }
}

data "azurerm_storage_account_sas" "uploads" {
  # Signed with the SECONDARY key on purpose: renewing the primary key revokes
  # every SAS already issued with it, and the CMS keeps working because this
  # token is signed with the other key. Order matters:
  #   1. apply -> the CMS secret holds a secondary-signed SAS
  #   2. az storage account keys renew --key primary   (old 5-year SAS dies)
  # Next rotation cycle: sign with primary and renew the secondary key.
  connection_string = azurerm_storage_account.main.secondary_connection_string
  https_only        = true
  signed_version    = "2022-11-02"

  start  = var.sas_start
  expiry = var.sas_expiry

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  # Object only: the CMS never touches container-level operations, and `delete`
  # at container scope would let a leaked SAS drop the whole container.
  resource_types {
    service   = false
    container = false
    object    = true
  }

  # Exactly what strapi/src/providers/upload-azure/index.ts calls:
  #   read   - serve/inspect assets
  #   write  - uploadData() -> Put Blob / Put Block List
  #   delete - deleteIfExists() -> Delete Blob; without it removed assets keep
  #            serving from a public-read container.
  # No list (no listBlobs/listContainers), no add (no append blobs), no create
  # (Put Blob accepts `w`, already granted).
  permissions {
    read   = true
    add    = false
    create = false
    write  = true
    delete = true
    list   = false
  }
}
