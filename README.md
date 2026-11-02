# phunggela-cms infrastructure

Terraform for the phunggela CMS database and container registry. The module is
deliberately limited to **PostgreSQL Flexible Server** and **Azure Container
Registry**. Container Apps is not managed here.

## Layout

```text
infra/
├── modules/
│   ├── postgres/          # server, database, firewall rules, DSN
│   └── acr/               # registry and admin credentials
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
│       ├── backend.tf     # Azure Blob remote state
│       ├── main.tf        # module calls
│       ├── moved.tf       # one-time state migration from the old root
│       ├── providers.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars  # git-ignored
├── .gitignore
└── README.md
```

Each module owns its inputs and outputs, so service-specific settings stay out
of `main.tf`.

## Remote state

Azure Blob Storage is the Azure equivalent of S3. The `azurerm` backend uses a
blob lease for locking.

The bootstrap resources already exist:

| Setting | Value |
|---|---|
| Subscription | `cb0f4bbe-bcbe-4466-a105-edb4bf1b21a5` |
| Resource group | `rg-cms-prod` |
| Storage account | `stcmsxs8ytf` |
| Container | `tfstate` |
| Prod key | `prod.terraform.tfstate` |
| Dev key | `dev.terraform.tfstate` |
| Staging key | `staging.terraform.tfstate` |

The storage account is intentionally **not** managed by Terraform. Recreate it
with the `az` CLI if needed:

```bash
az storage account create \
  --name stcmsxs8ytf \
  --resource-group rg-cms-prod \
  --location southafricanorth \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --https-only true \
  --access-tier Hot

SA_KEY="$(az storage account keys list \
  --resource-group rg-cms-prod \
  --account-name stcmsxs8ytf \
  --query '[0].value' -o tsv)"

az storage container create \
  --account-name stcmsxs8ytf \
  --account-key "$SA_KEY" \
  --name tfstate \
  --public-access off
```

Blob versioning and a 7-day soft delete are enabled on the account.

The deploying principal is Contributor on `rg-cms-prod` only and cannot create
role assignments, so the backend authenticates with the storage account key:

```bash
export ARM_ACCESS_KEY="$(az storage account keys list \
  --resource-group rg-cms-prod \
  --account-name stcmsxs8ytf \
  --query '[0].value' -o tsv)"
```

Do not commit or paste that key. If the principal later gets
**Storage Blob Data Contributor**, switch the backend to `use_azuread_auth =
true` and stop exporting `ARM_ACCESS_KEY`.

## Usage

```bash
cd environments/prod
export ARM_ACCESS_KEY="...from the command above..."

terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output -raw database_url
```

`dev` and `staging` use the same backend account with separate keys, but their
resource groups (`rg-cms-dev`, `rg-cms-staging`) must exist and the principal
must have access before planning.

## Secrets

- `terraform.tfvars` is git-ignored and holds environment-specific values,
  including the PostgreSQL administrator password for prod.
- `terraform.tfvars.example` is the tracked template.
- Never commit `terraform.tfstate`, `.terraform/`, plan files, or any
  `*.tfvars` file.
- For prod, keep `postgres_admin_password` set to the existing value. Leaving
  it null makes the postgres module generate a new password and rotate the
  live server on the next apply.
- ACR admin credentials are outputs; they are not stored in variables.

## Existing prod state

The previous root deployed:

- `pg-cms-xs8ytf` and database `cms`
- `acrcmsxs8ytf`

`environments/prod/moved.tf` maps those resources to `module.postgres` and
`module.acr`, so no server/registry is replaced. The old `0.0.0.0` firewall
rule is removed because this environment no longer has Container Apps.

## Checks

```bash
terraform fmt -check -recursive
cd environments/prod && terraform validate
cd environments/prod && terraform plan -refresh=false -detailed-exitcode
```

There is no CI or test suite yet. Always inspect the plan for unexpected
destroy or replace actions before applying.
