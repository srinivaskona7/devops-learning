# Cluster Hardening — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# kube-bench (CIS benchmark)
docker pull aquasec/kube-bench:latest

# kube-hunter (penetration probe)
docker pull aquasec/kube-hunter:latest

# Generate KMS-backed encryption config
cp encryption-config.yaml /etc/kubernetes/enc/encryption-config.yaml
chmod 0600 /etc/kubernetes/enc/encryption-config.yaml
```

## Apply policies / manifests

```bash
# Wire EncryptionConfiguration into kube-apiserver
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
# Add:
#   --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
# kubelet auto-restarts the static pod

# Production API server flags (kubeadm-config patch)
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
# --anonymous-auth=false
# --authorization-mode=Node,RBAC
# --audit-log-path=/var/log/audit.log
# --audit-policy-file=/etc/kubernetes/audit-policy.yaml
# --tls-min-version=VersionTLS12
# --profiling=false
# --service-account-lookup=true

# Disable kubelet read-only port (10255)
sudo vi /var/lib/kubelet/config.yaml
# readOnlyPort: 0
# anonymousAuth: false
# authorizationMode: Webhook
sudo systemctl restart kubelet
```

## Inspect / verify

```bash
# Run CIS benchmark on a node
docker run --rm --pid=host \
  -v /etc:/etc:ro -v /var:/var:ro \
  aquasec/kube-bench:latest run --benchmark cis-1.10

# Run as a Job in-cluster
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs job.batch/kube-bench

# kube-hunter — external probe
docker run -it --rm --network host \
  aquasec/kube-hunter:latest --remote <api-server-ip>

# kube-hunter — inside-cluster (assume attacker pod)
kubectl run kube-hunter --rm -it \
  --image=aquasec/kube-hunter:latest -- --pod

# Confirm encryption config is loaded
sudo grep encryption-provider-config /etc/kubernetes/manifests/kube-apiserver.yaml

# Confirm a Secret is actually encrypted in etcd
sudo ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/default/test-secret | hexdump -C | head

# Audit log tail
sudo tail -f /var/log/audit.log | jq .
```

## Common operations

```bash
# Re-encrypt all existing Secrets after enabling EncryptionConfiguration
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

# Rotate KMS key — add new key as first provider, re-encrypt, then remove old
sudo vi /etc/kubernetes/enc/encryption-config.yaml
kubectl get secrets -A -o json | kubectl replace -f -

# Rotate API server certs (kubeadm)
sudo kubeadm certs renew all
sudo systemctl restart kubelet

# Check cert expiry
sudo kubeadm certs check-expiration

# Upgrade control plane
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.30.x
```

## Cleanup

```bash
# Roll back EncryptionConfiguration: identity provider FIRST in list, then re-replace secrets
sudo vi /etc/kubernetes/enc/encryption-config.yaml
kubectl get secrets -A -o json | kubectl replace -f -

# Remove kube-bench Job
kubectl delete job kube-bench
```

## One-liners worth memorising

```bash
# Quick health: failures only
kubectl logs job.batch/kube-bench | grep -E '^\[FAIL\]'

# All control-plane process flags currently in effect
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -E '^\s+- --'

# Confirm anonymous auth disabled
curl -k https://<api-server>:6443/api    # expect 401, not 403

# Cert expiry one-liner
sudo kubeadm certs check-expiration | grep -v 'no '
```
