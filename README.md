# infra

Terraform for Azure Container Registry, PostgreSQL Flexible Server and the
Azure Container Apps environment.

## Layout

```text
infra/
├── modules/
│   ├── postgres/
│   ├── acr/
│   ├── aca/
│   ├── headless-cms/
│   ├── landing/
│   └── blob/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── .gitignore
```

Each environment is a root module that calls `modules/postgres`, `modules/acr`,
`modules/aca`, `modules/headless-cms`, `modules/landing` and `modules/blob` with
its own variables.

`modules/aca` owns one Container App Environment per environment plus the Log
Analytics workspace its logs go to. It creates no apps: each app gets its own
module (`aca_<app>`) that takes `module.aca.environment_id` and builds its URL
as `https://<app-name>.<module.aca.default_domain>`.

`modules/headless-cms` owns the Strapi Container App: image reference from ACR,
database wiring from `module.postgres`, and the Strapi boot secrets it
generates itself (APP_KEYS, API_TOKEN_SALT, ADMIN_JWT_SECRET,
TRANSFER_TOKEN_SALT, JWT_SECRET, ENCRYPTION_KEY, PREVIEW_SECRET). It never
creates a database or registry. Outputs: `url`, `fqdn`, `image`,
`latest_revision_name`, `latest_revision_fqdn`, `outbound_ip_addresses`, and
the sensitive `preview_secret` the frontend must reuse. `strapi_stripe_secret_key`
and `client_url` are omitted from the app when null instead of being set to an
empty string.

`modules/landing` owns the Next.js Container App (`ca-<prefix>-landing-<suffix>`)
on the same environment, port 3000, 0.5 CPU / 1Gi, max one replica. Its only
required input is `PREVIEW_SECRET`, passed in from
`module.headless_cms.preview_secret` — never generated again, because
`next/app/api/preview` compares it with the CMS-signed `secret` parameter and
answers 401 on mismatch. The image optimizer allowlist is baked by
`next.config.mjs` during `next build` (`--build-arg IMAGE_HOSTNAME=<cms-host>`,
bare host, no scheme), so it is deliberately not an env var here: setting it on
the container app changes nothing at runtime. `WEBSITE_URL` defaults to the
app's own ACA URL and is read at runtime by `app/sitemap.ts`; `app/robots.ts` is
prerendered at build time, so its `Sitemap:` line still carries the build-time
value until the image is rebuilt with `WEBSITE_URL`. No HTTP probes are
declared: `/api/preview`
returns 401 by design and every other route renders CMS data, so a 2xx probe
would restart the app whenever the CMS is down; the platform's TCP readiness is
used instead. Outputs: `url`, `fqdn`, `image`, `latest_revision_name`,
`latest_revision_fqdn`, `outbound_ip_addresses`.

`modules/blob` owns a StorageV2 account plus one container for Strapi uploads.
It is not wired into `modules/headless-cms`: its outputs exist so a local Strapi
can upload against real Azure storage before the app gets the credentials.

| Environment output | Local `strapi/.env` |
| --- | --- |
| `blob_sas_url` (`terraform output -raw blob_sas_url`, sensitive) | `AZURE_STORAGE_SAS_URL` |
| `blob_container_name` | `AZURE_STORAGE_CONTAINER_NAME` |
| `blob_cdn_url` | `AZURE_STORAGE_CDN_URL` |

`AZURE_STORAGE_CDN_URL` falls back to the blob base (`https://<account>.blob.core.windows.net/<container>`)
because no CDN exists yet; when one is added, point this at the CDN host and
drop the container segment. The provider writes `assets/<hash><ext>`, the
container allows anonymous read, and writes require the SAS. The SAS is an
account SAS with a fixed validity window (`sas_start` / `sas_expiry`), so it is
stable across applies.

## State

State lives in Azure Blob Storage (`stcmsxs8ytf`, container `tfstate`), one key
per environment: `dev.terraform.tfstate`, `staging.terraform.tfstate`,
`prod.terraform.tfstate`. The storage account is created manually and is not
managed here.

The deploying principal cannot manage role assignments, so the backend uses the
storage account key:

```bash
export ARM_ACCESS_KEY="$(az storage account keys list \
  --resource-group rg-cms-prod \
  --account-name stcmsxs8ytf \
  --query '[0].value' -o tsv)"
```

Do not commit that key.

## Networking

Container Apps and PostgreSQL are public; there is no VNet.

- `modules/aca` creates an external environment with no
  `infrastructure_subnet_id`. Container Apps egress IPs are assigned per app
  and are not known to Terraform when the PostgreSQL firewall rules are
  computed, so set `postgres_allow_azure_services = true` in an environment
  before creating its first app. The `0.0.0.0` rule plus the `sslmode=require`
  in `database_url` is the documented workaround.
- The environment declares the `Consumption` workload profile. An environment
  created without a workload profile can never gain one (it must be
  recreated), and only a workload profile environment can use a `/27` subnet
  in a VNet; consumption-only requires `/23`.

Upgrade path when a static egress IP or a non-public database is required:

1. Add `environments/<env>/vnet.tf`: a subnet of at least `/27` delegated to
   `Microsoft.App/environments`, a Standard NAT gateway with a static public
   IP, and a `/28` subnet for private endpoints. Make it a module only when a
   second environment needs it.
2. Pass that subnet to `modules/aca` as `infrastructure_subnet_id`. This
   replaces the environment, and with it every container app, and changes
   `default_domain`. Attach a custom domain to the apps first if the public URL
   must survive.
3. Keep PostgreSQL in public access mode and add a private endpoint on
   `privatelink.postgres.database.azure.com`, then disable public network
   access. Do not move the server to VNet integration: private endpoints are
   not supported on VNet-integrated servers.

NAT gateway plus its public IP cost about \$36/month per environment in
`southafricanorth`, before the public IPs and load balancer that a
VNet-injected environment also bills.

## Usage

```bash
cd environments/dev        # or staging / prod
cp terraform.tfvars.example terraform.tfvars   # then edit values
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output -raw database_url
```

## Secrets

- `*.tfvars`, `.terraform/`, and `*.tfstate` are git-ignored.
- Only `terraform.tfvars.example` is committed.
- In `prod`, keep `postgres_admin_password` set to the existing value; leaving
  it null generates a new password and rotates the live server.
- ACR admin credentials are outputs, not variables.

## Checks

```bash
terraform fmt -check -recursive
terraform validate        # inside each environment
```

Always read the plan for unexpected destroy/replace actions before applying.
