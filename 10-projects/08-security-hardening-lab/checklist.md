# Security Hardening — Checklist

Use this as a gate before declaring a cluster "production".

## Cluster posture
- [ ] kube-bench shows zero `[FAIL]` findings (or each is documented + accepted)
- [ ] Kubernetes version is within the last 3 minor releases (currently 1.28+)
- [ ] Audit logging enabled and shipped off-cluster
- [ ] API server endpoint is private (or public + IP-allowlisted)
- [ ] etcd is encrypted at rest (`--encryption-provider-config`)

## RBAC
- [ ] No ClusterRoleBindings to `system:masters` outside `kubeadm` defaults
- [ ] No `cluster-admin` in default ServiceAccounts
- [ ] Each namespace has its own least-privilege Role/RoleBinding
- [ ] `automountServiceAccountToken: false` by default; opt-in per workload

## Workload defaults (enforced via Kyverno or PSA)
- [ ] `runAsNonRoot: true`
- [ ] `readOnlyRootFilesystem: true`
- [ ] `allowPrivilegeEscalation: false`
- [ ] `capabilities.drop: [ALL]`
- [ ] `seccompProfile: { type: RuntimeDefault }`
- [ ] No `hostNetwork`, `hostPID`, `hostIPC`, `hostPath` mounts
- [ ] Resource requests AND limits set (CPU + memory)
- [ ] Image tag is a digest or immutable version (no `:latest`)

## Network
- [ ] Default-deny NetworkPolicy in every namespace
- [ ] Egress to external IPs explicitly allow-listed
- [ ] DNS egress to kube-system allowed
- [ ] Inter-namespace traffic explicitly declared
- [ ] Service mesh (Istio/Linkerd) for mTLS between services — optional but recommended

## Image supply chain
- [ ] All images scanned by Trivy in CI; pipeline fails on HIGH/CRITICAL
- [ ] Images signed with cosign; cluster verifies signature (Kyverno `verifyImages`)
- [ ] SBOM generated and stored
- [ ] Base images come from a curated internal registry (no random Docker Hub)

## Secrets
- [ ] No secrets committed to Git (gitleaks/trufflehog scan in CI)
- [ ] Cluster secrets sourced from External Secrets Operator → AWS Secrets Manager / Vault
- [ ] Secrets encrypted at rest in etcd (KMS provider)
- [ ] Service account tokens are projected (1h TTL), not the legacy long-lived secret

## Cloud auth
- [ ] No long-lived AWS access keys in CI — OIDC federation only
- [ ] IRSA roles scoped to a single namespace + service account
- [ ] Trust policies pin the GitHub Actions `sub` to a specific branch/env
- [ ] CloudTrail enabled in every region

## Operations
- [ ] Velero backups run daily; restore drill performed monthly
- [ ] Multi-AZ node groups; topologySpreadConstraints on critical workloads
- [ ] Pod Disruption Budgets on every workload with replicas > 1
- [ ] Trivy operator running; weekly review of new CVEs
- [ ] Falco (or equivalent) for runtime threat detection

## CI/CD
- [ ] Branch protection on `main` (signed commits, required reviews)
- [ ] Workflow permissions are minimal (`permissions:` block per job)
- [ ] Third-party actions pinned to commit SHA (not `@v1`)
- [ ] Dependabot enabled for actions, Docker, language deps
