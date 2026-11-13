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
│   ├── cms/
│   ├── landing/
│   ├── blob/
│   ├── vnet/
│   └── bastion/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── .gitignore
```

Each environment is a root module that calls `modules/postgres`, `modules/acr`,
`modules/aca`, `modules/cms`, `modules/landing` and `modules/blob` with its own
variables. `prod` additionally calls `modules/vnet` and, with
`enable_bastion_vm = true`, `modules/bastion`.

`modules/aca` owns one Container App Environment per environment plus the Log
Analytics workspace its logs go to. It creates no apps: each app gets its own
module (`aca_<app>`) that takes `module.aca.environment_id` and builds its URL
as `https://<app-name>.<module.aca.default_domain>`.

`modules/cms` owns the Strapi Container App: image reference from ACR,
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
`module.cms.preview_secret` — never generated again, because
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
Its SAS and container URL are wired into `modules/cms` (`AZURE_STORAGE_*`); the
outputs also let a local Strapi upload against real Azure storage.

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

`dev` and `staging`: Container Apps and PostgreSQL are public; there is no
VNet. `prod`: one VNet (`vnet-<prefix>-prod01`, 10.60.0.0/16) holds the
Container Apps subnet, the PostgreSQL delegated subnet and the bastion subnet;
PostgreSQL has `public_network_access_enabled = false` and no firewall rules,
so it is reachable only from inside that VNet, resolved by the private DNS zone
`<prefix>-prod01.postgres.database.azure.com`.

- `dev` and `staging` leave `infrastructure_subnet_id` null, so Container Apps
  assigns egress IPs per app and they are not known to Terraform when the
  PostgreSQL firewall rules are computed: set `postgres_allow_azure_services =
  true` there before creating the first app. The `0.0.0.0` rule plus the
  `sslmode=require` in `database_url` is the documented workaround.
- `prod` passes the Container Apps subnet and egresses through the NAT
  gateway, so `aca_egress_ip` is a single allow-listable address. Firewall
  rules stay empty: the server has no public endpoint to guard.
- The environment declares the `Consumption` workload profile. An environment
  created without a workload profile can never gain one (it must be
  recreated), and only a workload profile environment can use a `/27` subnet
  in a VNet; consumption-only requires `/23`.
- A VNet-integrated server cannot also carry private endpoints, so `prod` uses
  the delegated subnet instead of a private endpoint on
  `privatelink.postgres.database.azure.com`.

NAT gateway plus its public IP cost about \$36/month per environment in
`southafricanorth`, and a VNet-injected environment also bills the
platform-created `ME_*` resource group: one Standard load balancer and two
static public IPs.

## Bastion (prod)

`enable_bastion_vm = true` adds a Ubuntu 24.04 VM in `snet-bastion-prod01`
(`vm-bastion-<prefix>-prod01`). It is the only way into the private PostgreSQL
server, so it carries:

| Tool | Purpose |
| --- | --- |
| `psql`, `pg_dump`, `pg_restore` (`postgresql-client` 16) | terminal queries, dump/restore |
| Node.js 22 + npm, from NodeSource | Strapi/Node scripts against the DB |
| `pgweb` 0.17.0 | browser explorer: schema tree, SQL editor, CSV/JSON export |

No GUI runs on the VM: `pgweb` is a web server and the page is rendered by your
own browser through the tunnel. It stores no credentials and accepts
`database_url` (`sslmode=require` is handled by `lib/pq`).

`pgweb` runs as the `pgweb` systemd unit on `127.0.0.1:8081`. The NSG still
opens only port 22, and the web UI is reached through a tunnel:

```bash
terraform output -raw bastion_ssh_command
terraform output -raw bastion_pgweb_tunnel_command   # keep it running
# then open http://127.0.0.1:8081 and paste the DSN from
terraform output -raw database_url                   # postgres://…?sslmode=require
```

Put the forward in `~/.ssh/config` to skip the second command:

```sshconfig
Host bastion-prod
  HostName <bastion-public-ip>
  User azureuser
  LocalForward 8081 127.0.0.1:8081
  ServerAliveInterval 30
```

Then `ssh bastion-prod` both logs in and forwards; `http://127.0.0.1:8081`
works while the session lives.

In the pgweb connect form, either paste `database_url`, or fill it manually:
host `bcc2cad2cdfe.<prefix>-prod01.postgres.database.azure.com` (the `pg-…`
name works too, it is a CNAME inside the VNet), port `5432`, user `cmsadmin`,
password from `terraform output -raw db_password`, database `cms`, SSL mode
`require`. pgweb resolves that name from the VM — your laptop never has to.

The port stays closed on purpose: pgweb has no TLS (bind+auth only, plain
HTTP) and is writable by default (`--readonly` is opt-in), so a public 8081
would be an unauthenticated SQL console on the internet. Only 22 is open, from
`allowed_client_ips`.

The `database_url` host is the public name; it resolves to the server's private
address only from inside the VNet, which is why the tunnel exists. Same for
`psql`:

```bash
terraform output -raw postgres_fqdn
ssh azureuser@<bastion-public-ip>
psql "host=<fqdn> port=5432 dbname=cms user=cmsadmin sslmode=require"
```

`custom_data` is ForceNew: adding a tool changes the cloud-init payload and
replaces the VM. It holds no data, so `-/+` on `vm-bastion-*` in the plan is
expected.

### Restoring an existing dump

The CMS archive is **custom format** (`pg_dump -Fc`). If it was produced by a
newer `pg_dump` than the VM's client, `pg_restore` refuses it outright:

```text
pg_restore: error: unsupported version (1.16) in file header   # pg_dump 18 vs client 16
```

Install the matching client from PGDG (one-off, on the VM — `custom_data` is
ForceNew, so this is not in cloud-init):

```bash
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
  https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt noble-pgdg main" \
  | sudo tee /etc/apt/sources.list.d/pgdg.list
sudo apt-get update && sudo apt-get install -y postgresql-client-18
pg_restore --version   # 18.x — pg_wrapper picks the newest installed client
```

Then copy the archive and restore:

```bash
# laptop
scp cms.dump azureuser@<bastion-public-ip>:
# bastion
read -rs URL && export URL   # paste `terraform output -raw database_url`
pg_restore --no-owner --no-privileges -d "$URL" ~/cms.dump
```

- `--no-owner` is mandatory: the archive's objects belong to the source role
  (`admin`), which does not exist on the new server.
- `--no-privileges` skips `GRANT`s to roles that do not exist either.
- One error is expected and harmless:
  `SET transaction_timeout = 0` (`pg_dump 18` emits it, a 16 server rejects it).
  Nothing else should fail; `pg_restore` exits 1 on that alone.
- Verified end to end: 335 tables, `articles` 58 rows, `admin_users` 5 rows.

Take a backup before a re-restore: `pg_dump "$URL" -Fc -f ~/cms-$(date +%F).dump`.

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
