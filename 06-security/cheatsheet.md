# Security Cheatsheet

One-page command reference. See per-topic READMEs for context.

## RBAC

```bash
kubectl auth can-i list pods -n dev                              # current user
kubectl auth can-i delete deploy --as=system:serviceaccount:dev:app
kubectl auth can-i --list -n dev                                 # everything I can do
kubectl access-matrix for secrets -n dev                         # rakkess
kubectl who-can delete pods -n dev                               # who-can plugin

# Find dangerous bindings
kubectl get clusterrolebindings -o json \
  | jq '.items[] | select(.roleRef.name=="cluster-admin")'
```

## Pod Security Admission

```bash
# Label namespace
kubectl label ns app pod-security.kubernetes.io/enforce=restricted
kubectl label ns app pod-security.kubernetes.io/enforce-version=v1.30

# Dry-run a workload against PSA
kubectl apply --dry-run=server -f deploy.yaml
```

## Network Policies

```bash
# Confirm CNI enforces (curl should fail after default-deny)
kubectl run probe --rm -it --image=busybox --restart=Never -- wget -T 3 -O - http://service:80

kubectl get netpol -A
```

## Secrets

```bash
# Check if etcd is encrypted: secret bytes shouldn't be readable
ETCDCTL_API=3 etcdctl get /registry/secrets/default/foo --hex | head

# Rotate all secrets after enabling encryption
kubectl get secrets -A -o json | kubectl replace -f -

# Sealed-secrets
kubectl create secret generic foo --from-literal=k=v --dry-run=client -o yaml \
  | kubeseal --format yaml > foo.sealed.yaml
```

## Image security

```bash
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 IMG
trivy fs --scanners vuln,secret,misconfig .
trivy k8s --report summary cluster

syft IMG -o spdx-json > sbom.json
grype sbom:./sbom.json --fail-on high

# cosign keyless (in OIDC env, e.g. GH Actions)
cosign sign --yes IMG@DIGEST
cosign verify --certificate-identity-regexp "https://github.com/myorg/.*" \
              --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
              IMG@DIGEST
```

## Policy

```bash
kyverno test ./policies/
kyverno apply ./policies/ --resource ./manifests/
conftest test --policy ./rego ./manifests/
```

## Runtime

```bash
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=100
kubectl get tracingpolicy
```

## Hardening

```bash
# CIS benchmark
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs job/kube-bench

# Pen-test
kubectl run kh --rm -it --image=aquasec/kube-hunter:latest -- --pod
```

## Audit logs

```bash
# Tail an audit log on master (assumes kubeadm)
sudo tail -F /var/log/kubernetes/audit.log | jq 'select(.verb!="get" and .verb!="list")'

# Find who created a CRB recently
sudo jq 'select(.objectRef.resource=="clusterrolebindings" and .verb=="create")' \
  /var/log/kubernetes/audit.log
```

## Ten things to verify on a new cluster

1. `kubectl get psp` returns nothing (good — PSP removed); PSA labels present on namespaces
2. `kube-bench` clean of FAILs you don't accept
3. NetworkPolicy default-deny in every app namespace
4. EncryptionConfiguration in use (test with `etcdctl get` raw)
5. Audit log enabled, going to durable storage
6. `--anonymous-auth=false` on api-server and kubelets
7. No `cluster-admin` binding to humans (only break-glass)
8. Image registry restricted via Kyverno / Gatekeeper
9. Cosign verify policy in admission for prod
10. CNI confirmed as policy-enforcing (Calico / Cilium / managed)
