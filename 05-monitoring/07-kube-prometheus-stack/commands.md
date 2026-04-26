# kube-prometheus-stack — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create ns monitoring
ls values.yaml
```

## Run / deploy

```bash
# Install (pin a real version)
helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml \
  --version 65.x.x

# Upgrade after editing values.yaml
helm upgrade kps prometheus-community/kube-prometheus-stack \
  -n monitoring -f values.yaml

# Dry-run to preview manifests
helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring -f values.yaml --dry-run --debug | less
```

### Port-forward

```bash
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-alertmanager 9093
```

### Grafana admin password

```bash
kubectl -n monitoring get secret kps-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

## Query / verify

```bash
# Operator-managed CRDs
kubectl get prometheuses,alertmanagers,servicemonitors,podmonitors,prometheusrules -A

# Confirm scrape targets after install
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'

# Confirm a specific ServiceMonitor was picked up
curl -s http://localhost:9090/api/v1/targets | jq \
  '.data.activeTargets[] | select(.labels.job=="my-app") | .health'

# Sample PromQL via the in-cluster Prometheus
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=up{job="kubelet"}' | jq '.data.result | length'
```

### Add your own scrape

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  labels:
    release: kps          # MUST match serviceMonitorSelector in values.yaml
spec:
  selector:
    matchLabels: { app: my-app }
  endpoints:
    - port: metrics
      interval: 30s
```

```bash
kubectl apply -f my-app-servicemonitor.yaml
```

## Inspect

```bash
kubectl -n monitoring get pods
kubectl -n monitoring logs sts/prometheus-kps-kube-prometheus-stack-prometheus -c prometheus --tail=50
kubectl -n monitoring describe prometheus kps-kube-prometheus-stack-prometheus

# Operator decisions
kubectl -n monitoring logs deploy/kps-kube-prometheus-stack-operator | grep -i 'reconcil\|select'

# Loaded scrape config (rendered by operator)
kubectl -n monitoring exec sts/prometheus-kps-kube-prometheus-stack-prometheus \
  -c prometheus -- cat /etc/prometheus/config_out/prometheus.env.yaml | less
```

## Cleanup

```bash
helm uninstall kps -n monitoring
kubectl delete ns monitoring
# CRDs are NOT removed by helm uninstall — drop manually if desired:
kubectl get crd | grep monitoring.coreos.com | awk '{print $1}' | xargs -r kubectl delete crd
```

## One-liners worth memorising

```bash
# "Why isn't my metric showing up?"
kubectl get servicemonitor -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.release}{"\n"}{end}'
# -> if release label != selector value, operator ignores it.
```

```
Operator + CRDs = declarative monitoring. Edit ServiceMonitor, not prometheus.yml.
release: kps label is the #1 reason "my metrics aren't appearing".
Bundle = Prometheus + Alertmanager + Grafana + node-exporter + kube-state-metrics + Operator + ~30 alerts/dashboards.
Pin chart version in real life — never floating tags in prod.
```
