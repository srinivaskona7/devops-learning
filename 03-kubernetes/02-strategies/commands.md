# Kubernetes Deployment Strategies · commands quick-pick

> One-liners ordered by "what do I need when I'm paged at 03:00."

---

## Pane 1 — triage: what is deployed right now?

```bash
# Show all deployments with image versions
kubectl get deployments -o custom-columns=\
'NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image,READY:.status.readyReplicas,DESIRED:.spec.replicas'

# Show pod version labels (works when you label with version=)
kubectl get pods -L version,track,slot --sort-by='.metadata.labels.version'

# Which revision is currently running?
kubectl rollout history deployment/<name>

# What changed in a specific revision?
kubectl rollout history deployment/<name> --revision=3

# Show all endpoints (who is receiving traffic right now?)
kubectl get endpoints -o wide

# Quick health check: non-Running pods
kubectl get pods --field-selector=status.phase!=Running

# Events for a deployment (last 60 seconds of activity)
kubectl get events --field-selector=involvedObject.name=<deployment> \
  --sort-by='.lastTimestamp' | tail -20
```

---

## Pane 2 — rollback (fastest paths)

```bash
# === Rollback Option 1: kubectl undo (30-90 seconds) ===
kubectl rollout undo deployment/<name>

# Rollback to a specific revision
kubectl rollout undo deployment/<name> --to-revision=2

# Watch the rollback complete
kubectl rollout status deployment/<name> --watch

# === Rollback Option 2: Blue-Green selector flip (< 5 seconds) ===
# Flip back to blue
kubectl patch service <svc-name> \
  -p '{"spec":{"selector":{"slot":"blue"}}}'

# Verify the flip
kubectl get endpoints <svc-name>

# === Rollback Option 3: Argo Rollouts abort ===
kubectl argo rollouts abort <rollout-name>
kubectl argo rollouts get rollout <rollout-name> --watch

# === Rollback Option 4: Feature flag toggle (< 30 seconds) ===
# Unleash API
curl -s -X POST \
  http://unleash:4242/api/admin/features/<flag-name>/toggles/off \
  -H "Authorization: *:*.your-api-token"

# === Rollback Option 5: Scale canary to zero ===
kubectl scale deployment <canary-deployment> --replicas=0
kubectl scale deployment <stable-deployment> --replicas=<desired>
```

---

## Pane 3 — Recreate deployment

```bash
# Create a Recreate deployment (one-liner patch)
kubectl patch deployment <name> \
  -p '{"spec":{"strategy":{"type":"Recreate"}}}'

# Verify strategy
kubectl get deployment <name> -o jsonpath='{.spec.strategy.type}'
# Recreate

# Watch the downtime gap
kubectl get pods -l app=<label> --watch
# You will see all pods Terminating simultaneously before new ones start

# How long was the downtime? Check events
kubectl describe deployment <name> | grep -A5 "Events:"
```

---

## Pane 4 — RollingUpdate tuning

```bash
# Show current maxSurge / maxUnavailable
kubectl get deployment <name> -o jsonpath=\
'{.spec.strategy.rollingUpdate}'
# {"maxSurge":"25%","maxUnavailable":"25%"}

# Set to zero-downtime config (maxUnavailable=0)
kubectl patch deployment <name> -p '{
  "spec": {
    "strategy": {
      "type": "RollingUpdate",
      "rollingUpdate": {
        "maxSurge": 2,
        "maxUnavailable": 0
      }
    }
  }
}'

# Watch rolling progress with pod count
kubectl get pods -l app=<label> --watch

# Show rollout progress percentage
kubectl rollout status deployment/<name> --watch

# Pause a rolling update (hold at partial rollout)
kubectl rollout pause deployment/<name>

# Resume
kubectl rollout resume deployment/<name>

# Test zero-downtime: continuous probe during rollout
while true; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://<svc-ip>/)
  echo "$(date +%T) HTTP $STATUS"
  sleep 0.5
done
```

---

## Pane 5 — Blue-Green operations

```bash
# Check which slot is active
kubectl get service <svc-name> \
  -o jsonpath='{.spec.selector.slot}'

# Flip to green
kubectl patch service <svc-name> \
  -p '{"spec":{"selector":{"app":"<app>","slot":"green"}}}'

# Flip to blue
kubectl patch service <svc-name> \
  -p '{"spec":{"selector":{"app":"<app>","slot":"blue"}}}'

# Verify endpoints updated (pod IPs should match target slot)
kubectl get endpoints <svc-name> -o wide

# Cross-reference endpoint IPs to pods
kubectl get pods -o wide -L slot | grep <slot-name>

# Smoke test green before flip
kubectl port-forward deployment/<green-deployment> 9090:8080
curl -s http://localhost:9090/

# Cost: see both Deployments running
kubectl get deployments -l app=<app> \
  -o custom-columns='NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.readyReplicas'
```

---

## Pane 6 — Canary traffic split (manual)

```bash
# Check current traffic split (replica ratio)
STABLE=$(kubectl get deploy <stable> -o jsonpath='{.spec.replicas}')
CANARY=$(kubectl get deploy <canary> -o jsonpath='{.spec.replicas}')
TOTAL=$((STABLE + CANARY))
echo "stable: $STABLE/$TOTAL = $(( STABLE * 100 / TOTAL ))%"
echo "canary: $CANARY/$TOTAL = $(( CANARY * 100 / TOTAL ))%"

# Promote canary to 10% (1 of 10 total pods)
kubectl scale deployment <canary> --replicas=1
kubectl scale deployment <stable> --replicas=9

# Promote to 30%
kubectl scale deployment <canary> --replicas=3
kubectl scale deployment <stable> --replicas=7

# Promote to 50%
kubectl scale deployment <canary> --replicas=5
kubectl scale deployment <stable> --replicas=5

# Full promotion (100% canary, scale stable to 0)
kubectl scale deployment <stable> --replicas=0
kubectl scale deployment <canary> --replicas=10

# Rollback: scale canary to 0, stable back up
kubectl scale deployment <canary> --replicas=0
kubectl scale deployment <stable> --replicas=10

# Header-based canary routing (Nginx Ingress)
kubectl annotate ingress <ingress-name> \
  nginx.ingress.kubernetes.io/canary="true" \
  nginx.ingress.kubernetes.io/canary-by-header="X-Canary" \
  --overwrite

# Test header routing
curl -H "X-Canary: always" http://<host>/
curl -H "X-Canary: never"  http://<host>/
```

---

## Pane 7 — Argo Rollouts

```bash
# Install Argo Rollouts controller
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install kubectl plugin (macOS)
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-darwin-amd64
chmod +x kubectl-argo-rollouts-darwin-amd64&& sudo mv $_ /usr/local/bin/kubectl-argo-rollouts

# Install kubectl plugin (Linux)
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64 && sudo mv $_ /usr/local/bin/kubectl-argo-rollouts

# Live rollout dashboard
kubectl argo rollouts get rollout <name> --watch

# Trigger new rollout (update image)
kubectl argo rollouts set image <rollout-name> \
  <container>=<new-image>:<tag>

# Promote past a pause step
kubectl argo rollouts promote <rollout-name>

# Promote all remaining steps (skip all pauses)
kubectl argo rollouts promote <rollout-name> --full

# Abort (triggers auto-rollback to stable)
kubectl argo rollouts abort <rollout-name>

# Retry a failed rollout
kubectl argo rollouts retry rollout <rollout-name>

# List all rollouts and their status
kubectl argo rollouts list rollouts

# Show analysis run results
kubectl get analysisruns
kubectl describe analysisrun <name>

# Open Argo Rollouts dashboard
kubectl argo rollouts dashboard
# Opens http://localhost:3100

# Convert an existing Deployment to a Rollout
kubectl argo rollouts convert deployment <name>
```

---

## Pane 8 — Flagger

```bash
# Install Flagger (Istio provider)
helm repo add flagger https://flagger.app && helm repo update
helm upgrade -i flagger flagger/flagger \
  --namespace=istio-system \
  --set meshProvider=istio \
  --set metricsServer=http://prometheus:9090

# Install Flagger load tester (needed for webhooks)
helm upgrade -i flagger-loadtester flagger/loadtester \
  --namespace=default

# Check Flagger controller logs
kubectl logs -n istio-system deploy/flagger -f

# List all Canary resources
kubectl get canaries --all-namespaces

# Watch canary status
kubectl get canary <name> --watch

# Describe canary (shows events + current weight)
kubectl describe canary <name>

# Trigger a canary by updating the Deployment image
kubectl set image deployment/<name> <container>=<image>:<tag>

# Manually approve promotion (if using webhooks with approval)
# POST to your webhook URL or via Slack slash command

# Force rollback (delete canary pod to trigger metric failure)
kubectl delete pod -l app=<name>-canary

# View Flagger events
kubectl get events --field-selector=reason=Synced

# Check VirtualService weights (Istio)
kubectl get virtualservice <name> \
  -o jsonpath='{.spec.http[0].route}' | python3 -m json.tool
```

---

## Pane 9 — Shadow / Mirror traffic (Istio)

```bash
# Verify Istio injection is enabled on namespace
kubectl get namespace default \
  --show-labels | grep istio-injection

# Enable injection
kubectl label namespace default istio-injection=enabled

# Check VirtualService mirror config
kubectl get virtualservice <name> \
  -o jsonpath='{.spec.http[0].mirror}'

# Check mirror percentage
kubectl get virtualservice <name> \
  -o jsonpath='{.spec.http[0].mirrorPercentage}'

# Watch shadow service logs (mirrored requests)
kubectl logs -l version=v2 -f --tail=50

# Compare v1 vs v2 error rates in Prometheus
# rate(istio_requests_total{destination_app="<app>-shadow",response_code=~"5.."}[5m])
# rate(istio_requests_total{destination_app="<app>",response_code=~"5.."}[5m])

# Remove mirror when confident
kubectl patch virtualservice <name> --type=json \
  -p='[{"op":"remove","path":"/spec/http/0/mirror"}]'
```

---

## Pane 10 — Feature flags (Unleash)

```bash
# Install Unleash via Helm
helm repo add unleash https://docs.getunleash.io/helm-charts && helm repo update
helm install unleash unleash/unleash \
  --namespace unleash --create-namespace \
  --set postgresql.auth.password=unleash123 \
  --set unleash.auth.adminPassword=admin123 \
  --wait

# Port-forward UI
kubectl port-forward -n unleash svc/unleash 4242:4242

# Create a feature flag
curl -s -X POST http://localhost:4242/api/admin/features \
  -H "Authorization: *:*.unleash-insecure-api-token" \
  -H "Content-Type: application/json" \
  -d '{"name":"my-feature","type":"release","enabled":false}'

# Enable flag for all users
curl -s -X POST \
  http://localhost:4242/api/admin/features/my-feature/toggles/on \
  -H "Authorization: *:*.unleash-insecure-api-token"

# Disable flag (instant rollback)
curl -s -X POST \
  http://localhost:4242/api/admin/features/my-feature/toggles/off \
  -H "Authorization: *:*.unleash-insecure-api-token"

# Add gradual rollout strategy (10% of users)
curl -s -X POST \
  http://localhost:4242/api/admin/features/my-feature/strategies \
  -H "Authorization: *:*.unleash-insecure-api-token" \
  -H "Content-Type: application/json" \
  -d '{"name":"gradualRolloutUserId","parameters":{"percentage":"10","groupId":"my-feature"}}'

# List all feature flags
curl -s http://localhost:4242/api/admin/features \
  -H "Authorization: *:*.unleash-insecure-api-token" | jq '.features[] | {name,enabled}'

# Cleanup
helm uninstall unleash -n unleash
kubectl delete namespace unleash
```

---

## Pane 11 — Observation patterns (all strategies)

```bash
# Watch pods change during any rollout (keep open in side pane)
kubectl get pods --watch -L version,slot,track

# Count ready vs desired across all deployments
kubectl get deployments -o wide

# Continuous HTTP probe (paste in side terminal before triggering deploy)
SVC_IP=$(kubectl get svc <name> -o jsonpath='{.spec.clusterIP}')
while true; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$SVC_IP/)
  echo "$(date +%T) HTTP $CODE"
  sleep 0.2
done

# Watch HPA scaling during rollout
kubectl get hpa --watch

# Describe a pod's events (startup, readiness failures)
kubectl describe pod <pod-name> | grep -A20 "Events:"

# Check that readiness probe passes
kubectl exec -it <pod-name> -- wget -qO- http://localhost:8080/
```

---

## Pane 12 — Zero-downtime verification checklist

```bash
# 1. Confirm strategy type
kubectl get deployment <name> -o jsonpath='{.spec.strategy.type}'

# 2. Confirm readiness probe is set
kubectl get deployment <name> \
  -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}'

# 3. Confirm minReadySeconds (prevents too-fast rolling)
kubectl get deployment <name> -o jsonpath='{.spec.minReadySeconds}'
# Set to 30 if empty:
kubectl patch deployment <name> -p '{"spec":{"minReadySeconds":30}}'

# 4. Confirm terminationGracePeriodSeconds (default 30s)
kubectl get deployment <name> \
  -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}'

# 5. Confirm PodDisruptionBudget exists
kubectl get pdb -l app=<label>
# Create one if missing:
kubectl apply -f - <<'EOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: <name>-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: <label>
EOF

# 6. Confirm preStop hook (graceful drain)
kubectl get deployment <name> \
  -o jsonpath='{.spec.template.spec.containers[0].lifecycle.preStop}'
```

---

## Strategy comparison — one-liner recall

```
Recreate:      kubectl patch deploy X -p '{"spec":{"strategy":{"type":"Recreate"}}}'
RollingUpdate: kubectl patch deploy X -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":2,"maxUnavailable":0}}}}'
Blue-Green:    kubectl patch svc X -p '{"spec":{"selector":{"slot":"green"}}}'
Canary:        kubectl scale deploy canary --replicas=1; kubectl scale deploy stable --replicas=9
A/B:           kubectl annotate ing X nginx.ingress.kubernetes.io/canary-by-cookie="ab-group"
Shadow:        kubectl apply -f virtual-service-mirror.yaml   # (Istio VirtualService with mirror:)
Feature flag:  curl -X POST http://unleash/api/.../toggles/on -H "Authorization: ..."
Flagger:       kubectl apply -f canary.yaml; kubectl set image deploy/X container=image:v2
Argo:          kubectl argo rollouts set image X container=image:v2
Rollback:      kubectl rollout undo deployment/X   # or: kubectl argo rollouts abort X
```
