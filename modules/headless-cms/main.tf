locals {
  cms_app_name = "ca-${var.name_prefix}-${var.suffix}"

  cms_image = format(
    "%s/%s:%s",
    var.acr_login_server,
    var.cms_image_repository,
    var.cms_image_tag,
  )

  # Stable public URL: the app FQDN is <name>.<environment default domain>.
  # Do not derive this from ingress.fqdn, which changes when ingress is paused.
  cms_url = "https://${local.cms_app_name}.${var.app_environment_default_domain}"

  # Strapi parses APP_KEYS as a comma-separated list (config/server.ts).
  app_keys = join(",", random_password.strapi_app_keys[*].result)

  has_client_url = var.client_url != null && var.client_url != ""
  has_stripe_key = var.strapi_stripe_secret_key != null && var.strapi_stripe_secret_key != ""
}

resource "random_password" "strapi_app_keys" {
  count   = 2
  length  = 32
  special = false
}

resource "random_password" "strapi_api_token_salt" {
  length  = 32
  special = false
}

resource "random_password" "strapi_admin_jwt_secret" {
  length  = 32
  special = false
}

resource "random_password" "strapi_transfer_token_salt" {
  length  = 32
  special = false
}

resource "random_password" "strapi_jwt_secret" {
  length  = 32
  special = false
}

# Strapi derives one per boot when unset, which breaks anything it encrypted
# on a previous revision.
resource "random_password" "strapi_encryption_key" {
  length  = 32
  special = false
}

# Shared with the frontend's draft-mode route: the value must match on both
# sides, so it is exported instead of being set per app.
resource "random_password" "strapi_preview_secret" {
  length  = 32
  special = false
}

resource "azurerm_container_app" "headless_cms" {
  name                         = local.cms_app_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  # Set explicitly: the API always reports the profile back, so leaving it
  # unset makes every plan show a removal from state.
  workload_profile_name = var.workload_profile_name
  revision_mode         = "Single"

  tags = var.tags

  # The deploying principal is Contributor on this resource group only and
  # cannot create AcrPull role assignments, so the registry admin account is
  # used instead. Requires admin_enabled on the registry.
  secret {
    name  = "acr-password"
    value = var.acr_admin_password
  }

  secret {
    name  = "database-host"
    value = var.database_host
  }

  secret {
    name  = "database-port"
    value = var.database_port
  }

  secret {
    name  = "database-name"
    value = var.database_name
  }

  secret {
    name  = "database-username"
    value = var.database_username
  }

  secret {
    name  = "database-password"
    value = var.database_password
  }

  secret {
    name  = "preview-secret"
    value = random_password.strapi_preview_secret.result
  }

  secret {
    name  = "app-keys"
    value = local.app_keys
  }

  secret {
    name  = "api-token-salt"
    value = random_password.strapi_api_token_salt.result
  }

  secret {
    name  = "admin-jwt-secret"
    value = random_password.strapi_admin_jwt_secret.result
  }

  secret {
    name  = "transfer-token-salt"
    value = random_password.strapi_transfer_token_salt.result
  }

  secret {
    name  = "jwt-secret"
    value = random_password.strapi_jwt_secret.result
  }

  secret {
    name  = "encryption-key"
    value = random_password.strapi_encryption_key.result
  }

  dynamic "secret" {
    for_each = local.has_stripe_key ? [1] : []

    content {
      name  = "stripe-secret-key"
      value = var.strapi_stripe_secret_key
    }
  }

  registry {
    server               = var.acr_login_server
    username             = var.acr_admin_username
    password_secret_name = "acr-password"
  }

  template {
    min_replicas                     = var.cms_paused ? 0 : 1
    max_replicas                     = 1
    termination_grace_period_seconds = 30

    container {
      name   = "cms"
      image  = local.cms_image
      cpu    = 1
      memory = "2Gi"

      env {
        name  = "DATABASE_CLIENT"
        value = "postgres"
      }

      env {
        name  = "DATABASE_SCHEMA"
        value = "public"
      }

      env {
        name        = "DATABASE_HOST"
        secret_name = "database-host"
      }

      env {
        name        = "DATABASE_PORT"
        secret_name = "database-port"
      }

      env {
        name        = "DATABASE_NAME"
        secret_name = "database-name"
      }

      env {
        name        = "DATABASE_USERNAME"
        secret_name = "database-username"
      }

      env {
        name        = "DATABASE_PASSWORD"
        secret_name = "database-password"
      }

      env {
        name  = "DATABASE_SSL"
        value = "true"
      }

      env {
        name  = "DATABASE_SSL_REJECT_UNAUTHORIZED"
        value = "true"
      }

      env {
        name        = "PREVIEW_SECRET"
        secret_name = "preview-secret"
      }

      env {
        name        = "APP_KEYS"
        secret_name = "app-keys"
      }

      env {
        name        = "API_TOKEN_SALT"
        secret_name = "api-token-salt"
      }

      env {
        name        = "ADMIN_JWT_SECRET"
        secret_name = "admin-jwt-secret"
      }

      env {
        name        = "TRANSFER_TOKEN_SALT"
        secret_name = "transfer-token-salt"
      }

      env {
        name        = "JWT_SECRET"
        secret_name = "jwt-secret"
      }

      env {
        name        = "ENCRYPTION_KEY"
        secret_name = "encryption-key"
      }

      # Strapi loads this at boot (src/api/order/controllers/order.ts), so an
      # empty value must be omitted rather than set to "".
      dynamic "env" {
        for_each = local.has_stripe_key ? [1] : []

        content {
          name        = "STRIPE_SECRET_KEY"
          secret_name = "stripe-secret-key"
        }
      }

      # Used for admin preview origins and password-reset links.
      dynamic "env" {
        for_each = local.has_client_url ? [1] : []

        content {
          name  = "CLIENT_URL"
          value = var.client_url
        }
      }

      # Strapi's built-in health endpoint returns 204 once the HTTP server and
      # database bootstrap are ready. The admin panel build makes the first
      # boot slow, so the startup probe allows up to ~3 minutes.
      startup_probe {
        transport               = "HTTP"
        port                    = 1337
        path                    = "/_health"
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 18
        initial_delay           = 10
      }

      readiness_probe {
        transport               = "HTTP"
        port                    = 1337
        path                    = "/_health"
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 3
      }

      liveness_probe {
        transport               = "HTTP"
        port                    = 1337
        path                    = "/_health"
        interval_seconds        = 30
        timeout                 = 5
        failure_count_threshold = 3
        initial_delay           = 60
      }
    }
  }

  ingress {
    # Paused removes public ingress so nothing can wake the zero-replica app.
    external_enabled           = !var.cms_paused
    target_port                = 1337
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}
