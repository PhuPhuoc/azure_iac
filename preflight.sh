#!/usr/bin/env bash
#
# preflight.sh — gate that runs before every apply. Read-only: it only runs
# fmt, validate and plan (plan reads state and refreshes), then inspects the
# plan JSON. It never changes infrastructure.
#
#   ./preflight.sh prod          # check prod, print the apply command
#   ./preflight.sh dev           # dev: plans if deployed, warns if empty
#   ./preflight.sh dev --new     # first deploy: an empty state is expected
#   ./preflight.sh --audit prod  # re-print the gate for an existing plan only
#
# Exit: 0 = plan is clean, safe to apply
#       1 = failure, or the plan destroys/replaces/rotates something
#       2 = not initialised / not deployed yet (not a code error)
#
# Deliberately no -target, -replace, -refresh=false: those hide exactly what
# this script is looking for.

set -euo pipefail

ENV=""
NEW_DEPLOY=0
AUDIT=0
for arg in "$@"; do
  case "$arg" in
    --new) NEW_DEPLOY=1 ;;
    --audit) AUDIT=1 ;;
    dev | prod) ENV=$arg ;;
    -h | --help)
      sed -n "2,17p" "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "invalid argument: $arg" >&2
      exit 1
      ;;
  esac
done

case "$ENV" in
  dev | prod) ;;
  *)
    echo "usage: $0 <dev|prod> [--new] [--audit]" >&2
    exit 1
    ;;
esac

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DIR="$ROOT/environments/$ENV"
PLAN="/tmp/tf-preflight-$ENV.tfplan"
JSON="/tmp/tf-preflight-$ENV.plan.json"
BLOCK="/tmp/tf-preflight-$ENV.block"

# prod is the make default, so its commands need no ENV= suffix.
if [ "$ENV" = prod ]; then
  SHOW_CMD="make show"
  APPLY_CMD="make apply"
  CHECK_CMD="make check"
else
  SHOW_CMD="make show ENV=$ENV"
  APPLY_CMD="make apply ENV=$ENV"
  CHECK_CMD="make check ENV=$ENV"
fi

export TF_IN_AUTOMATION=1

say() { printf '\n== %s\n' "$*"; }
die() {
  printf 'STOP: %s\n' "$*" >&2
  exit 1
}
skip() {
  printf 'SKIP: %s\n' "$*" >&2
  exit 2
}

# --- plan inspection ------------------------------------------------------
# Shared by the full run and by --audit, so `make apply` re-prints exactly the
# same verdict as `make check`.

print_changes() {
  say "changes"
  jq -r '
    [ .resource_changes[] | select((.change.actions|join(">")) != "no-op") ] as $c
    | if ($c|length) == 0 then "  no changes"
      else
        ($c | group_by(.change.actions|join(">"))
            | map("\(.[0].change.actions|join(">"))=\(length)") | join("  ")),
        ($c[] | "  \(.change.actions|join(">"))  \(.address)")
      end' "$JSON"
}

print_env_warnings() {
  local out
  out=$(jq -r '
    def envs: [ .. | objects | select((.env?|type) == "array") | .env[].name ];
    .resource_changes[]
    | select(.type == "azurerm_container_app")
    | .change
    | ((.before|envs) - (.after|envs)) as $lost
    | select(($lost|length) > 0)
    | "  REMOVED: \($lost|join(", "))  <- variable missing, do not apply"' "$JSON" 2>/dev/null || true)
  [ -n "$out" ] || return 0
  say "warning: container app env vars being removed (usually a missing TF_VAR_)"
  printf '%s\n' "$out"
}

run_gate() {
  say "8/8 apply gate"
  jq -r '
    .resource_changes[]
    | select((.change.actions|join(">")) != "no-op")
    | if (.change.actions|index("delete")) then
        "BLOCK destroy/replace: \(.address)"
      elif .type == "random_password" then
        "BLOCK secret rotation: \(.address) — Strapi/Postgres would switch to a new secret"
      elif (.type == "azurerm_postgresql_flexible_server"
            and ((.change.before.administrator_password? // "") != (.change.after.administrator_password? // ""))) then
        "BLOCK Postgres admin password change: \(.address) — the container app keeps the old password"
      else empty end' "$JSON" >"$BLOCK"

  if [ -s "$BLOCK" ]; then
    sed 's/^/  /' "$BLOCK"
    printf '\nThe plan destroys, replaces or rotates something. Read it:\n  %s\n  (equivalent: terraform -chdir=environments/%s show -no-color %s)\n' \
      "$SHOW_CMD" "$ENV" "$PLAN" >&2
    printf 'To proceed, change the code/variables until the plan is update-only, then re-run %s.\n' "$CHECK_CMD" >&2
    exit 1
  fi
  echo "  no destroy/replace, no secret rotation"
}

if [ "$AUDIT" -eq 1 ]; then
  [ -f "$JSON" ] || die "no plan at $JSON — run $CHECK_CMD first."
  echo "audit: env=$ENV plan=$(basename "$PLAN")"
  print_changes
  print_env_warnings
  run_gate
  exit 0
fi

# --- full run -------------------------------------------------------------

[ -d "$DIR" ] || die "$DIR does not exist"
command -v terraform >/dev/null || die "terraform not found in PATH"
command -v jq >/dev/null || die "jq not found in PATH"

echo "preflight: env=$ENV dir=environments/$ENV"

cd "$ROOT"

say "1/8 format (whole repo, modules/ included)"
terraform fmt -check -recursive -diff ||
  die "code is not formatted. Fix with: make fmt"

say "2/8 no local state file"
[ ! -e "$DIR/terraform.tfstate" ] ||
  die "$DIR/terraform.tfstate exists — the backend was never initialised or was initialised wrong. Planning or applying against local state can create a second copy of the resources."

say "3/8 input variables"
[ -f "$DIR/terraform.tfvars" ] ||
  die "missing environments/$ENV/terraform.tfvars (gitignored). Start from terraform.tfvars.example and fill in real values, otherwise the plan is wrong: it silently uses the variable defaults instead."

cd "$DIR"

say "4/8 init real backend + validate"
init_args=(-input=false -lockfile=readonly -lock-timeout=60s)
if [ -f backend.hcl ]; then
  init_args+=(-backend-config=backend.hcl)
fi
if ! terraform init "${init_args[@]}"; then
  if [ "$ENV" = dev ]; then
    echo "dev backend is not configured — falling back to an offline validate" >&2
    terraform init -input=false -backend=false -lockfile=readonly
    terraform validate
    skip "dev backend is not initialised (see environments/dev/backend.tf), cannot plan. fmt and validate passed."
  fi
  die "terraform init failed. Check ARM_ACCESS_KEY (key of the storage account holding state), the backend key, and access to that storage account."
fi

terraform validate

say "5/8 backend points at the right env and subscription"
meta=.terraform/terraform.tfstate
backend_store=$(jq -r '.backend.config.storage_account_name // ""' "$meta" 2>/dev/null || true)
backend_key=$(jq -r '.backend.config.key // ""' "$meta" 2>/dev/null || true)
backend_sub=$(jq -r '.backend.config.subscription_id // ""' "$meta" 2>/dev/null || true)

if [ -z "$backend_store" ]; then
  if [ "$ENV" = dev ]; then
    skip "dev backend has no storage coordinates (environments/dev/backend.tf is empty): state would live on this machine. Fill in resource_group_name + storage_account_name, or init with -backend-config, then re-run. fmt and validate passed."
  fi
  die "backend does not point at any storage account (state would live on this machine). Check environments/$ENV/backend.tf."
fi
echo "  storage=$backend_store key=$backend_key"

case "$backend_key" in
  "$ENV".* | "$ENV"/*) ;;
  *) die "backend key '$backend_key' does not belong to env '$ENV'. Initialising with the wrong key plans/applies against another env's state." ;;
esac

if [ -n "$backend_sub" ] && [ -n "${ARM_SUBSCRIPTION_ID:-}" ] && [ "$backend_sub" != "$ARM_SUBSCRIPTION_ID" ]; then
  die "backend pins subscription $backend_sub but ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID. The refresh would run with a different login."
fi
if [ -z "$backend_sub" ]; then
  active_sub=$(az account show --query id -o tsv 2>/dev/null || echo "?")
  echo "  backend does not pin a subscription — using the az CLI default: $active_sub"
fi

say "6/8 state must hold real resources (catches a wrong backend key/subscription)"
count=$(terraform state list | wc -l | tr -d ' ')
echo "  state: $count resources ($ENV)"
if [ "$count" -eq 0 ]; then
  if [ "$ENV" = dev ] || [ "$NEW_DEPLOY" -eq 1 ]; then
    echo "WARNING: empty state, the plan will create everything. Only correct for a first deploy." >&2
  else
    die "empty state. Almost certainly a wrong backend key or subscription: applying would create a second set of resources. Re-read the 'Key:'/'Storage Account:' lines from terraform init, and check az account show."
  fi
fi

say "7/8 plan (real refresh, same variables as apply)"
vf=(-input=false -lock-timeout=60s -out="$PLAN")
[ -f terraform.tfvars ] && vf+=(-var-file=terraform.tfvars)
[ -f secrets.tfvars ] && vf+=(-var-file=secrets.tfvars)

# A missing TF_VAR_ does not fail the plan: it silently shows an env var being
# REMOVED (STRAPI_STRIPE_SECRET_KEY, CMS_SMTP_*...) and apply then removes it.
if env | grep -q '^TF_VAR_'; then
  env | grep -E '^TF_VAR_' | sed 's/=.*/=<hidden>/' | sort | sed 's/^/  /'
else
  echo "  (no TF_VAR_ set)"
fi

if ! terraform plan "${vf[@]}"; then
  printf '\nplan failed. Usual causes:\n' >&2
  printf '  - the target resource group does not exist (preflight never creates one), or\n' >&2
  printf '  - the login has no permission on the resource group/subscription, or\n' >&2
  printf '  - wrong ARM_SUBSCRIPTION_ID.\n' >&2
  printf 'Check: az account show -o table && az group show -n <rg> -o table\n' >&2
  if [ "$ENV" = dev ]; then
    skip "dev is not deployed (resource group or network does not exist yet, or no permission). fmt and validate passed."
  fi
  exit 1
fi
terraform show -json "$PLAN" >"$JSON"

print_changes
print_env_warnings
run_gate

printf '\nOK: plan is clean.\n  plan:  %s\n  json:  %s\n  read:  %s\n  apply: %s\n' \
  "$PLAN" "$JSON" "$SHOW_CMD" "$APPLY_CMD"
