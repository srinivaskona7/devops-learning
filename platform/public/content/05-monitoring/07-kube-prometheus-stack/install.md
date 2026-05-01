# Install kube-prometheus-stack

## Prereqs

- Kubernetes 1.27+
- Helm 3.12+
- A default StorageClass (or change `gp3` in `values.yaml`)
- 4 GiB free RAM in the cluster

## 1. Add the Helm repo

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

## 2. Namespace

```bash
kubectl create namespace monitoring
```

## 3. Install (pin the chart version!)

```bash
helm install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version 65.5.1 \
  --values values.yaml \
  --wait --timeout 10m
```

## 4. Verify

```bash
kubectl -n monitoring get pods
# Expected: prometheus-kps-... 2/2, alertmanager-kps-... 2/2,
#          kps-grafana-..., kps-operator-..., kps-kube-state-metrics-...,
#          kps-prometheus-node-exporter-... (one per node)

kubectl -n monitoring get servicemonitors
kubectl -n monitoring get prometheusrules
```

## 5. Access UIs (port-forward)

```bash
# Grafana
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
# user: admin   pass: from values.yaml or `kubectl get secret kps-grafana -o yaml`

# Prometheus
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090

# Alertmanager
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-alertmanager 9093
```

## 6. Add your own ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: my-ns
  labels:
    release: kps   # IMPORTANT: must match the operator's selector
spec:
  selector:
    matchLabels: { app: my-app }
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

## 7. Upgrade

```bash
helm upgrade kps prometheus-community/kube-prometheus-stack \
  -n monitoring -f values.yaml --version 65.5.x
```

## 8. Uninstall

```bash
helm uninstall kps -n monitoring
# CRDs are not removed by helm. Remove manually if needed:
kubectl delete crd $(kubectl get crd | grep monitoring.coreos.com | awk '{print $1}')
```

## Troubleshooting

| Symptom | Cause |
|---------|-------|
| ServiceMonitor not picked up | Missing `release: kps` label OR `serviceMonitorSelectorNilUsesHelmValues: true` |
| Prometheus OOM | Cardinality explosion — see `10-cost-and-cardinality` |
| Grafana datasource missing | Check `additionalDataSources` in values |
| etcd alerts firing on managed clusters | Disable `defaultRules.rules.etcd` |
