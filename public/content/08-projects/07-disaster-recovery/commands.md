# Project 07 (Disaster Recovery — Velero) — Commands

> Quick pickup reference. Full walkthrough in `README.md` and `velero-install.md`.

## Prerequisites
```bash
aws sts get-caller-identity
kubectl get nodes -L topology.kubernetes.io/zone   # multi-AZ visible
velero version --client-only || brew install velero

export REGION=us-east-1
export BUCKET=velero-backups-$(date +%s)
```

## Build
Bucket + (dev) credentials file:
```bash
aws s3api create-bucket --bucket $BUCKET --region $REGION
aws s3api put-bucket-versioning --bucket $BUCKET \
  --versioning-configuration Status=Enabled

cat > credentials-velero <<EOF
[default]
aws_access_key_id=$AWS_ACCESS_KEY_ID
aws_secret_access_key=$AWS_SECRET_ACCESS_KEY
EOF
```
For prod-grade IRSA install, follow `velero-install.md` instead.

## Deploy
```bash
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.10.0 \
  --bucket $BUCKET \
  --backup-location-config region=$REGION \
  --snapshot-location-config region=$REGION \
  --secret-file ./credentials-velero \
  --use-node-agent

kubectl -n velero wait --for=condition=available deploy/velero --timeout=180s

# Demo workload
kubectl create ns proj07-demo
kubectl -n proj07-demo create deploy nginx --image=nginx:1.27-alpine
kubectl -n proj07-demo expose deploy nginx --port=80

# First backup
velero backup create demo-1 --include-namespaces proj07-demo
velero backup describe demo-1 --details

# Recurring schedule
velero schedule create daily-all \
  --schedule="0 2 * * *" \
  --ttl 168h \
  --exclude-namespaces kube-system,velero
```

## Verify
```bash
velero backup get
velero schedule get
velero backup logs demo-1

# DR drill
kubectl delete namespace proj07-demo
kubectl get ns proj07-demo                       # NotFound

velero restore create --from-backup demo-1
velero restore get
kubectl -n proj07-demo get all                   # nginx is back

# AZ spread test
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: spread-test }
spec:
  replicas: 6
  selector: { matchLabels: { app: spread-test } }
  template:
    metadata: { labels: { app: spread-test } }
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector: { matchLabels: { app: spread-test } }
      containers:
        - { name: pause, image: registry.k8s.io/pause:3.10 }
EOF

kubectl get pods -l app=spread-test -o wide
```

## Cleanup
```bash
velero schedule delete daily-all --confirm
velero backup delete demo-1 --confirm
velero uninstall --force
kubectl delete deploy spread-test
kubectl delete ns proj07-demo 2>/dev/null || true
aws s3 rb s3://$BUCKET --force
rm -f credentials-velero
```

## One-liners worth memorising
```bash
# Ad-hoc backup of one app's namespace
velero backup create adhoc-$(date +%s) --include-namespaces proj01

# Restore into a different namespace
velero restore create --from-backup demo-1 \
  --namespace-mappings proj07-demo:proj07-demo-restored

# etcd snapshot (kubeadm clusters only — EKS handles it for you)
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/backups/etcd-$(date +%F).db

# Confirm backup succeeded from CLI
velero backup get -o json | jq '.items[] | {name:.metadata.name, status:.status.phase}'
```
