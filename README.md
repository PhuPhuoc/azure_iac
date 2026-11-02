# infra

Terraform for Azure Container Registry and PostgreSQL Flexible Server.

## Layout

```text
infra/
├── modules/
│   ├── postgres/
│   └── acr/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── .gitignore
```

Each environment is a root module that calls `modules/postgres` and
`modules/acr` with its own variables.

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
