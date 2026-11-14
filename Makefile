# Pre-apply gate. Nothing here applies prod on its own.
#
# ENV defaults to prod: `make check` / `make show` / `make apply` already mean
# prod, no need to type ENV=prod. Use ENV=dev (or the -dev targets) for dev.
SHELL := /bin/bash
ENV ?= prod
DIR := environments/$(ENV)
PLAN := /tmp/tf-preflight-$(ENV).tfplan

# Only printed when the caller needs a non-default env.
ENV_HINT := $(if $(filter prod,$(ENV)),, ENV=$(ENV))

.PHONY: help check check-dev check-prod show apply apply-dev apply-prod fmt clean

help: ## list targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  make %-10s %s\n", $$1, $$2}'

# Exit 2 means "not initialised / not deployed": report it and stay green,
# because it is not a code error.
check: ## gate before apply (prod by default, ENV=dev for dev)
	@./preflight.sh $(ENV); s=$$?; \
	if [ $$s -eq 2 ]; then echo "-> not initialised or not deployed: not a code error"; exit 0; fi; \
	exit $$s

check-dev: ## gate for dev
	@./preflight.sh dev; s=$$?; \
	if [ $$s -eq 2 ]; then echo "-> dev is not deployed: not a code error"; exit 0; fi; \
	exit $$s

check-prod: ## gate for prod
	@./preflight.sh prod; s=$$?; \
	if [ $$s -eq 2 ]; then echo "-> prod is not initialised: not a code error"; exit 0; fi; \
	exit $$s

# A saved plan can only be read from the root module that produced it: run
# terraform from environments/$(ENV), never from the repo root.
show: ## read the plan produced by the last check (prod by default)
	@[ -f $(PLAN) ] || { echo "no plan at $(PLAN). Run: make check$(ENV_HINT)"; exit 1; }
	terraform -chdir=$(DIR) show -no-color $(PLAN) | less -R

# Apply the exact plan `make check` produced. Terraform refuses a stale plan
# (state changed since plan time) — that is a feature, do not work around it.
apply: ## apply the checked plan (prod by default, asks yes/no)
	@[ -f $(PLAN) ] || { echo "no plan at $(PLAN). Run: make check$(ENV_HINT) first."; exit 1; }
	@./preflight.sh --audit $(ENV) || true
	cd $(DIR) && terraform apply $(PLAN)

apply-dev: ## apply the checked dev plan
	@$(MAKE) --no-print-directory apply ENV=dev

apply-prod: ## apply the checked prod plan
	@$(MAKE) --no-print-directory apply ENV=prod

fmt: ## format the whole repo (modules/ and environments/)
	terraform fmt -recursive

clean: ## remove the temporary plan/json files in /tmp
	rm -f /tmp/tf-preflight-*.tfplan /tmp/tf-preflight-*.plan.json /tmp/tf-preflight-*.block
