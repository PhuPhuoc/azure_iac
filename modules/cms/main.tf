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

  # All-or-nothing: the email plugin reads these at boot and nodemailer fails
  # at send time when host/auth are half configured, so a partial config is
  # rejected by the precondition on the container app instead.
  has_smtp = var.smtp_host != null && var.smtp_host != ""

  # Empty strings are as broken as nulls: SMTP_USERNAME="" authenticates as
  # nobody and SMTP_DEFAULT_FROM="" fails in nodemailer, both only at send time.
  smtp_missing = [
    for name, value in {
      smtp_username         = var.smtp_username
      smtp_password         = var.smtp_password
      smtp_default_from     = var.smtp_default_from
      smtp_default_reply_to = var.smtp_default_reply_to
      contact_inbox         = var.contact_inbox
    } : name if value == null || value == ""
  ]

  # SMTP_PASSWORD is delivered through a secret, everything else as plain env.
  smtp_env = local.has_smtp ? {
    SMTP_HOST             = var.smtp_host
    SMTP_PORT             = tostring(var.smtp_port)
    SMTP_SECURE           = tostring(var.smtp_secure)
    SMTP_USERNAME         = var.smtp_username
    SMTP_DEFAULT_FROM     = var.smtp_default_from
    SMTP_DEFAULT_REPLY_TO = var.smtp_default_reply_to
    CONTACT_INBOX         = var.contact_inbox
  } : {}
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
  # Multiple revisions keep the previous one alive while the new one is being
  # provisioned, so a bad image or a rejected database credential leaves traffic
  # on the old revision and there is something to shift back to. Single revision
  # replaces the only revision in place.
  revision_mode = "Multiple"

  tags = var.tags

  lifecycle {
    precondition {
      condition     = !local.has_smtp || length(local.smtp_missing) == 0
      error_message = "smtp_host is set, so smtp_username, smtp_password, smtp_default_from, smtp_default_reply_to and contact_inbox must all be set to non-empty values."
    }
  }

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

  secret {
    name  = "blob-sas-url"
    value = var.blob_sas_url
  }

  secret {
    name  = "blob-container-name"
    value = var.blob_container_name
  }

  secret {
    name  = "blob-cdn-url"
    value = var.blob_cdn_url
  }

  dynamic "secret" {
    for_each = local.has_stripe_key ? [1] : []

    content {
      name  = "stripe-secret-key"
      value = var.strapi_stripe_secret_key
    }
  }

  dynamic "secret" {
    for_each = local.has_smtp ? [1] : []

    content {
      name  = "smtp-password"
      value = var.smtp_password
    }
  }

  registry {
    server               = var.acr_login_server
    username             = var.acr_admin_username
    password_secret_name = "acr-password"
  }

  template {
    min_replicas                     = 1
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

      env {
        name        = "AZURE_STORAGE_SAS_URL"
        secret_name = "blob-sas-url"
      }

      env {
        name        = "AZURE_STORAGE_CONTAINER_NAME"
        secret_name = "blob-container-name"
      }

      env {
        name        = "AZURE_STORAGE_CDN_URL"
        secret_name = "blob-cdn-url"
      }

      # Strapi email plugin (config/plugins.ts). SMTP_SECURE is a string
      # because env.bool parses it. CONTACT_INBOX is the form controller's
      # notification recipient (falls back to ADMIN_EMAIL).
      dynamic "env" {
        for_each = local.smtp_env

        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.has_smtp ? [1] : []

        content {
          name        = "SMTP_PASSWORD"
          secret_name = "smtp-password"
        }
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
    # Explicit: the provider default is false (internal-only), which would break
    # the public CMS URL reported by the url output.
    external_enabled           = true
    target_port                = 1337
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

# ARM reports the container app as created as soon as the resource exists, so a
# revision that never starts (missing image tag, unreachable database, rejected
# credentials) still leaves `terraform apply` green while prod is down. This gate
# checks the revision apply just created and fails the apply when it never serves
# /_health.
#
# Readiness is taken from the revision's own FQDN, not the app FQDN: during a
# rollout the app FQDN still answers from the previous revision, which would hide
# a broken new one. The revision FQDN bypasses traffic weights.
#
# revision.healthState is not used: it reports "unknown" while the startup probe
# is still running, and runningState is "RunningAtMaxScale" once max_replicas is
# reached, so neither is a reliable healthy signal on its own.
resource "terraform_data" "revision_health" {
  count = var.revision_health_gate ? 1 : 0

  triggers_replace = azurerm_container_app.headless_cms.latest_revision_name

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -uo pipefail
      command -v curl >/dev/null || { echo "curl is required for the revision health gate" >&2; exit 1; }
      app='${azurerm_container_app.headless_cms.name}'
      rg='${var.resource_group_name}'
      rev='${azurerm_container_app.headless_cms.latest_revision_name}'
      url='https://${azurerm_container_app.headless_cms.latest_revision_fqdn}/_health'
      for _ in $(seq 1 20); do
        running=$(az containerapp revision show -n "$app" -g "$rg" --revision "$rev" \
          --query properties.runningState -o tsv 2>/dev/null)
        # Failed/Stopped are terminal (container exited, image pull rejected), so
        # waiting out the remaining probes only delays the error.
        case "$running" in Failed|Stopped) break ;; esac
        code=$(curl -s -o /dev/null -w '%%{http_code}' --max-time 5 "$url" 2>/dev/null || true)
        if [ "$code" = "200" ] || [ "$code" = "204" ]; then
          echo "revision $rev serves $url (HTTP $code, runningState $running)"
          exit 0
        fi
        sleep 15
      done
      echo "revision $rev never became healthy (runningState $${running:-unknown}, last HTTP $${code:-none} on $url)" >&2
      az containerapp logs show -n "$app" -g "$rg" --tail 50 >&2 || true
      exit 1
    EOT
  }
}
