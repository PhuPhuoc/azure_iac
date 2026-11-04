locals {
  landing_app_name = "ca-${var.name_prefix}-landing-${var.suffix}"

  landing_image = format(
    "%s/%s:%s",
    var.acr_login_server,
    var.landing_image_repository,
    var.landing_image_tag,
  )

  # Stable public URL: the app FQDN is <name>.<environment default domain>.
  landing_url = "https://${local.landing_app_name}.${var.app_environment_default_domain}"

  # app/robots.ts and app/sitemap.ts build absolute URLs from WEBSITE_URL and
  # fall back to http://localhost:3000, so the app's own URL is the default.
  website_url = var.website_url == null ? local.landing_url : var.website_url
}

resource "azurerm_container_app" "landing" {
  name                         = local.landing_app_name
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

  # Must be the exact value the CMS signs the draft-mode redirect with
  # (app/api/preview compares it with the `secret` query parameter and answers
  # 401 otherwise), so it is passed in rather than generated here.
  secret {
    name  = "preview-secret"
    value = var.preview_secret
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
      name   = "landing"
      image  = local.landing_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "PREVIEW_SECRET"
        secret_name = "preview-secret"
      }

      env {
        name  = "WEBSITE_URL"
        value = local.website_url
      }

      # No HTTP probes on purpose: /api/preview answers 401 without the secret
      # and every other route renders CMS data, so a 2xx probe would restart
      # the app whenever the CMS is unavailable. TCP readiness (the platform
      # default) is what the ingress uses instead.
    }
  }

  ingress {
    external_enabled           = true
    target_port                = 3000
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}
