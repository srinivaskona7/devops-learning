# Grafana — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Required layout
ls provisioning/datasources.yaml \
   provisioning/dashboards.yaml \
   dashboard-k8s-cluster.json
```

## Run / deploy

```bash
# Single container, provisioned from CWD
docker run -d --name grafana -p 3000:3000 \
  -v $PWD/provisioning:/etc/grafana/provisioning \
  -v $PWD/dashboard-k8s-cluster.json:/var/lib/grafana/dashboards/k8s.json \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  grafana/grafana:11.2.0
# UI: http://localhost:3000  (admin / admin)

# On the same docker network as Prom/Loki/Tempo so datasource URLs resolve
docker network create obs 2>/dev/null
docker network connect obs grafana
```

## Query / verify

```bash
# Health
curl -s http://localhost:3000/api/health | jq .

# List datasources (auth basic)
curl -s -u admin:admin http://localhost:3000/api/datasources | jq '.[].name'

# Test a datasource
curl -s -u admin:admin http://localhost:3000/api/datasources/uid/PROM_UID/health | jq .

# Proxy a PromQL query through Grafana
curl -sG -u admin:admin \
  "http://localhost:3000/api/datasources/proxy/uid/PROM_UID/api/v1/query" \
  --data-urlencode 'query=up' | jq .
```

### Panel queries to memorise

```text
RPS:           sum(rate(http_requests_total[5m]))
Error %:       100 * <error ratio recording rule>
Top-N noisy:   topk(10, sum by (service)(rate(http_requests_total[5m])))
Latency heat:  sum by (le)(rate(http_request_duration_seconds_bucket[5m]))
Live logs:     {namespace="$ns",pod="$pod"}    # LogQL
```

### Variables

```text
namespace = label_values(kube_pod_info, namespace)
pod       = label_values(kube_pod_info{namespace="$namespace"}, pod)
```

## Inspect

```bash
# Dashboards loaded by provisioning
curl -s -u admin:admin http://localhost:3000/api/search?type=dash-db | jq '.[].title'

# Confirm provisioning paths
docker exec grafana ls /etc/grafana/provisioning/datasources \
                       /etc/grafana/provisioning/dashboards \
                       /var/lib/grafana/dashboards

# Tail logs
docker logs -f grafana | grep -i 'error\|provision'

# Reset admin password from inside the container
docker exec -it grafana grafana-cli admin reset-admin-password newpass
```

## Cleanup

```bash
docker rm -f grafana
docker volume rm grafana-storage 2>/dev/null
```

## One-liners worth memorising

```bash
# Render dashboard JSON via API
curl -s -u admin:admin http://localhost:3000/api/dashboards/uid/<UID> | jq .dashboard > out.json

# Force re-provision (Grafana watches files)
docker restart grafana
```

```text
Never click your way to a dashboard in production. Provision YAML/JSON.
provisioning/datasources/  -> backends
provisioning/dashboards/   -> JSON loader
$namespace + $pod variables = one dashboard fits all pods.
Unified Alerting (Grafana 8+) crosses datasources and reuses Alertmanager contact points.
```
