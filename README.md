# infra

Terraform for Azure Container Registry, PostgreSQL Flexible Server and the
Azure Container Apps environment.

## Layout

```text
infra/
├── modules/
│   ├── postgres/
│   ├── acr/
│   └── aca/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── .gitignore
```

Each environment is a root module that calls `modules/postgres`, `modules/acr`
and `modules/aca` with its own variables.

`modules/aca` owns one Container App Environment per environment plus the Log
Analytics workspace its logs go to. It creates no apps: each app gets its own
module (`aca_<app>`) that takes `module.aca.environment_id` and builds its URL
as `https://<app-name>.<module.aca.default_domain>`.

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
