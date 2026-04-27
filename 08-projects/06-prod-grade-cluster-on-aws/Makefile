###############################################################################
# Makefile — Project 06: Production-Grade EKS Cluster
#
# Prerequisites:
#   - terraform >= 1.6
#   - aws CLI >= 2 (configured with credentials)
#   - kubectl
#   - helm >= 3.14
#   - infracost (for 'make cost')
#   - tflint (for 'make tflint')
#   - checkov (for 'make checkov')
###############################################################################

TF_DEV   := infra/terraform/environments/dev
TF_PROD  := infra/terraform/environments/prod
TF_ROOT  := infra/terraform
CLUSTER_NAME ?= dev-eks
AWS_REGION   ?= us-east-1

.DEFAULT_GOAL := help

# ── Help ─────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo ""
	@echo "  Project 06 — Production-Grade EKS Cluster"
	@echo ""
	@echo "  Dev environment:"
	@echo "    make plan-dev        Terraform plan (dev)"
	@echo "    make apply-dev       Terraform apply (dev) — ~20 min"
	@echo "    make destroy-dev     Terraform destroy (dev)"
	@echo ""
	@echo "  Prod environment:"
	@echo "    make plan-prod       Terraform plan (prod)"
	@echo "    make apply-prod      Terraform apply (prod)"
	@echo "    make destroy-prod    Terraform destroy (prod)"
	@echo ""
	@echo "  Cluster operations:"
	@echo "    make kubeconfig      Update kubeconfig for dev cluster"
	@echo "    make kubeconfig-prod Update kubeconfig for prod cluster"
	@echo "    make nodes           List cluster nodes"
	@echo "    make addons          List addon pods"
	@echo ""
	@echo "  Code quality:"
	@echo "    make tflint          Terraform lint (all modules)"
	@echo "    make checkov         Policy-as-code security scan"
	@echo "    make tfsec           Secret and misconfiguration scan"
	@echo "    make validate        Terraform validate (all envs)"
	@echo "    make fmt             Terraform format check"
	@echo ""
	@echo "  Cost:"
	@echo "    make cost            Infracost estimate (dev)"
	@echo "    make cost-prod       Infracost estimate (prod)"
	@echo ""

# ── Dev environment ───────────────────────────────────────────────────────────
.PHONY: init-dev
init-dev:
	terraform -chdir=$(TF_DEV) init -upgrade

.PHONY: plan-dev
plan-dev: init-dev
	terraform -chdir=$(TF_DEV) plan -out=tfplan.dev

.PHONY: apply-dev
apply-dev: init-dev
	terraform -chdir=$(TF_DEV) apply -auto-approve tfplan.dev

.PHONY: destroy-dev
destroy-dev:
	@echo "WARNING: This will destroy the dev EKS cluster and ALL resources."
	@echo "Press Ctrl-C to cancel, or Enter to continue..."
	@read _confirm
	terraform -chdir=$(TF_DEV) destroy -auto-approve

# ── Prod environment ──────────────────────────────────────────────────────────
.PHONY: init-prod
init-prod:
	terraform -chdir=$(TF_PROD) init -upgrade

.PHONY: plan-prod
plan-prod: init-prod
	terraform -chdir=$(TF_PROD) plan -out=tfplan.prod

.PHONY: apply-prod
apply-prod:
	@echo "PRODUCTION APPLY — requires manual confirmation"
	terraform -chdir=$(TF_PROD) apply tfplan.prod

.PHONY: destroy-prod
destroy-prod:
	@echo "DANGER: This destroys production. Type 'yes-destroy-prod' to confirm:"
	@read confirm && [ "$$confirm" = "yes-destroy-prod" ]
	terraform -chdir=$(TF_PROD) destroy

# ── Kubeconfig ────────────────────────────────────────────────────────────────
.PHONY: kubeconfig
kubeconfig:
	aws eks update-kubeconfig \
	  --name dev-$(CLUSTER_NAME) \
	  --region $(AWS_REGION)

.PHONY: kubeconfig-prod
kubeconfig-prod:
	aws eks update-kubeconfig \
	  --name prod-eks \
	  --region $(AWS_REGION)

# ── Cluster inspection ────────────────────────────────────────────────────────
.PHONY: nodes
nodes:
	kubectl get nodes -o wide

.PHONY: addons
addons:
	kubectl get pods -A -l 'app.kubernetes.io/managed-by=Helm'

.PHONY: nodepools
nodepools:
	kubectl get nodepools,ec2nodeclasses

.PHONY: karpenter-logs
karpenter-logs:
	kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f --tail=100

# ── Code quality ──────────────────────────────────────────────────────────────
.PHONY: validate
validate: init-dev
	terraform -chdir=$(TF_ROOT) validate
	terraform -chdir=$(TF_DEV) validate
	terraform -chdir=$(TF_PROD) validate

.PHONY: fmt
fmt:
	terraform fmt -recursive -check $(TF_ROOT)

.PHONY: fmt-fix
fmt-fix:
	terraform fmt -recursive $(TF_ROOT)

.PHONY: tflint
tflint:
	@command -v tflint > /dev/null || (echo "Install tflint: https://github.com/terraform-linters/tflint" && exit 1)
	tflint --recursive --config=$(CURDIR)/.tflint.hcl $(TF_ROOT)

.PHONY: checkov
checkov:
	@command -v checkov > /dev/null || (echo "Install checkov: pip install checkov" && exit 1)
	checkov -d $(TF_ROOT) \
	  --framework terraform \
	  --skip-check CKV_AWS_79 \
	  --compact \
	  --quiet

.PHONY: tfsec
tfsec:
	@command -v tfsec > /dev/null || (echo "Install tfsec: brew install tfsec" && exit 1)
	tfsec $(TF_ROOT) --minimum-severity HIGH

# ── Cost estimation ───────────────────────────────────────────────────────────
.PHONY: cost
cost:
	@command -v infracost > /dev/null || (echo "Install infracost: https://www.infracost.io/docs/#quick-start" && exit 1)
	infracost breakdown --path $(TF_DEV) --format table

.PHONY: cost-prod
cost-prod:
	infracost breakdown --path $(TF_PROD) --format table

.PHONY: cost-diff
cost-diff:
	infracost diff \
	  --path $(TF_DEV) \
	  --compare-to $(TF_PROD) \
	  --format table

# ── Smoke test (post-apply) ───────────────────────────────────────────────────
.PHONY: smoke
smoke: kubeconfig
	@echo "=== Node status ==="
	kubectl get nodes
	@echo ""
	@echo "=== System pods ==="
	kubectl get pods -n kube-system
	@echo ""
	@echo "=== Karpenter pods ==="
	kubectl get pods -n karpenter
	@echo ""
	@echo "=== cert-manager pods ==="
	kubectl get pods -n cert-manager
	@echo ""
	@echo "=== EBS CSI pods ==="
	kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
	@echo ""
	@echo "=== Karpenter NodePool ==="
	kubectl get nodepool,ec2nodeclass 2>/dev/null || echo "(Karpenter CRDs not yet installed)"
