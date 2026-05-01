# Kubernetes Core · commands quick-pick

> One-liners ordered by "what do I need when I'm paged at 03:00."
> All commands assume a working `kubectl` context. `$NS` = your namespace.

---

## Pane 1 — triage (first 60 seconds)

```bash
# All pods — spot anything not Running/Completed
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Recent events sorted by time — find the root cause fast
kubectl get events -A --sort-by='.lastTimestamp' | tail -30

# Node capacity vs what's allocated
kubectl describe nodes | grep -A 8 "Allocated resources"

# Pods not ready (Ready condition False)
kubectl get pods -A -o wide | grep -v "Running\|Completed\|Terminating"

# Find pods with restarts > 0
kubectl get pods -A --sort-by='.status.containerStatuses[0].restartCount' | tail -20
```

---

## Pane 2 — pod deep-dive

```bash
# Describe a pod (events, probe failures, resource limits, node assignment)
kubectl describe pod $POD -n $NS

# Logs — current container
kubectl logs $POD -n $NS --tail=100 -f

# Logs — previous (crashed) container instance
kubectl logs $POD -n $NS -c $CONTAINER --previous

# Logs — all containers in a pod
kubectl logs $POD -n $NS --all-containers=true

# Exec into a running container
kubectl exec -it $POD -n $NS -- /bin/sh

# Debug distroless/slim image — ephemeral container
kubectl debug -it pod/$POD -n $NS --image=busybox:1.36 --target=$CONTAINER -- sh

# Debug a node — chroot /host for full node filesystem
kubectl debug node/$NODE -it --image=ubuntu -- bash
```

---

## Pane 3 — field extraction (jsonpath)

```bash
# Pod IP
kubectl get pod $POD -o jsonpath='{.status.podIP}'

# Node a pod landed on
kubectl get pod $POD -o jsonpath='{.spec.nodeName}'

# All pod IPs in a namespace (tab-separated name + IP)
kubectl get pods -n $NS -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# All images running in every namespace
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u

# Every container's resource limits in a namespace
kubectl get pods -n $NS -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.containers[*]}  {.name}: req={.resources.requests.cpu}/{.resources.requests.memory} lim={.resources.limits.cpu}/{.resources.limits.memory}{"\n"}{end}{end}'

# Service ClusterIP + ports
kubectl get svc -n $NS -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.clusterIP}{"\t"}{.spec.ports[*].port}{"\n"}{end}'

# PVC → PV binding status
kubectl get pvc -n $NS -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.spec.volumeName}{"\n"}{end}'
```

---

## Pane 4 — rollouts & deployments

```bash
# Watch a rollout progress
kubectl rollout status deployment/$DEPLOY -n $NS -w

# Rollout history (all revisions)
kubectl rollout history deployment/$DEPLOY -n $NS

# Inspect a specific revision
kubectl rollout history deployment/$DEPLOY -n $NS --revision=3

# Rollback to previous
kubectl rollout undo deployment/$DEPLOY -n $NS

# Rollback to specific revision
kubectl rollout undo deployment/$DEPLOY -n $NS --to-revision=2

# Pause a rollout (batch changes before they apply)
kubectl rollout pause deployment/$DEPLOY -n $NS
kubectl set image deployment/$DEPLOY app=nginx:1.25 -n $NS
kubectl rollout resume deployment/$DEPLOY -n $NS

# Scale
kubectl scale deployment/$DEPLOY --replicas=5 -n $NS

# Force restart all pods in a Deployment (zero-downtime)
kubectl rollout restart deployment/$DEPLOY -n $NS

# See the ReplicaSets behind a Deployment
kubectl get rs -n $NS -l app=$APP --sort-by='.metadata.creationTimestamp'
```

---

## Pane 5 — services & networking

```bash
# Show all Services + ClusterIP + ports
kubectl get svc -A -o wide

# Show Endpoints for a Service (are pods being selected?)
kubectl get endpoints $SVC -n $NS

# Port-forward to a pod (no Ingress needed)
kubectl port-forward pod/$POD -n $NS 8080:80

# Port-forward to a Service
kubectl port-forward svc/$SVC -n $NS 8080:80

# Test Service routing from inside the cluster
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -v http://$SVC.$NS.svc.cluster.local/

# DNS lookup inside cluster
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- \
  nslookup $SVC.$NS.svc.cluster.local

# List all Ingress rules
kubectl get ingress -A -o wide

# Inspect Ingress
kubectl describe ingress $INGRESS -n $NS
```

---

## Pane 6 — config, secrets, volumes

```bash
# Create a ConfigMap from literal values
kubectl create configmap my-config --from-literal=key1=value1 --from-literal=key2=value2

# Create a ConfigMap from a file
kubectl create configmap my-config --from-file=./config.yaml

# Decode a Secret value (prove base64 is NOT encryption)
kubectl get secret $SECRET -n $NS -o jsonpath='{.data.password}' | base64 -d

# List all Secrets (shows types, not values)
kubectl get secrets -n $NS

# Create a Secret from literal
kubectl create secret generic $SECRET --from-literal=password=mysecret -n $NS

# Show PVC status + bound PV
kubectl get pvc -n $NS

# Describe a PV (reclaim policy, access mode, StorageClass)
kubectl describe pv $PV

# Watch PVC transition from Pending → Bound
kubectl get pvc $PVC -n $NS -w
```

---

## Pane 7 — RBAC audit

```bash
# Can a ServiceAccount perform an action?
kubectl auth can-i list pods \
  --as=system:serviceaccount:$NS:$SA

kubectl auth can-i get secrets \
  --as=system:serviceaccount:$NS:$SA -n $NS

# List ALL permissions for a ServiceAccount
kubectl auth can-i --list \
  --as=system:serviceaccount:$NS:$SA

# Who can do X to resource Y? (requires kubectl 1.28+)
kubectl who-can list pods -n $NS      # if krew plugin installed
# Without plugin:
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .subjects[].name'

# List all RoleBindings in a namespace
kubectl get rolebindings,clusterrolebindings -n $NS -o wide

# Describe a Role (see exact verbs + resources)
kubectl describe role $ROLE -n $NS
kubectl describe clusterrole $CLUSTERROLE
```

---

## Pane 8 — namespaces & quotas

```bash
# List all namespaces + status
kubectl get namespaces

# Quota usage — how much of the budget is consumed?
kubectl describe resourcequota -n $NS

# LimitRange — see injected defaults
kubectl describe limitrange -n $NS

# All pods across all namespaces with resource usage (needs metrics-server)
kubectl top pods -A --sort-by=cpu

# All nodes resource usage
kubectl top nodes
```

---

## Pane 9 — probes & health

```bash
# See probe configuration for every container in a pod
kubectl get pod $POD -n $NS -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}  liveness: {.livenessProbe}{"\n"}  readiness: {.readinessProbe}{"\n"}  startup: {.startupProbe}{"\n"}{end}'

# Check if pod is ready (exit 0 if ready, 1 if not)
kubectl wait pod/$POD -n $NS --for=condition=Ready --timeout=60s

# Watch all pod conditions
kubectl describe pod $POD -n $NS | grep -A 6 "Conditions:"

# See probe failure events
kubectl get events -n $NS --field-selector reason=Unhealthy --sort-by='.lastTimestamp'

# Count liveness failures in the last hour
kubectl get events -n $NS --field-selector reason=Killing \
  --sort-by='.lastTimestamp' | grep "liveness probe"
```

---

## Pane 10 — dry-run & validate

```bash
# Generate YAML without applying (client-side)
kubectl create deployment web --image=nginx --replicas=3 \
  --dry-run=client -o yaml > deploy.yaml

# Server-side dry-run — catches admission webhook rejections
kubectl apply -f deploy.yaml --dry-run=server

# Validate a manifest locally (no cluster needed)
kubectl apply -f deploy.yaml --validate=true --dry-run=client

# Inline API documentation
kubectl explain pod.spec.containers.resources
kubectl explain deployment.spec.strategy.rollingUpdate
kubectl explain ingress.spec.rules

# Diff current cluster state vs local file
kubectl diff -f deploy.yaml
```

---

## Pane 11 — copy, exec, attach

```bash
# Copy file FROM pod
kubectl cp $NS/$POD:/var/log/app.log ./app.log

# Copy file TO pod
kubectl cp ./config.yaml $NS/$POD:/etc/app/config.yaml

# Exec command in specific container (multi-container pod)
kubectl exec -it $POD -n $NS -c $CONTAINER -- /bin/sh

# Attach to container stdin (useful for interactive apps)
kubectl attach -it $POD -n $NS

# Run a one-shot debug pod and auto-delete it
kubectl run debug-shell --image=nicolaka/netshoot --rm -it --restart=Never -- bash
```

---

## Pane 12 — cluster-wide triage one-liners

```bash
# Pods on a specific node
kubectl get pods -A --field-selector spec.nodeName=$NODE

# Pods using a specific image
kubectl get pods -A -o jsonpath='{range .items[?(@.spec.containers[0].image=="nginx:1.24")]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'

# All pods with their QoS class (Guaranteed/Burstable/BestEffort)
kubectl get pods -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,QOS:.status.qosClass'

# Non-running pods and their reason
kubectl get pods -A --field-selector=status.phase!=Running -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,REASON:.status.reason'

# Force delete a stuck pod (use sparingly — data loss risk with stateful apps)
kubectl delete pod $POD -n $NS --grace-period=0 --force

# Cordon + drain a node for maintenance
kubectl cordon $NODE
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data
# After maintenance:
kubectl uncordon $NODE

# Watch custom columns (live refresh)
kubectl get pods -n $NS \
  -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,IP:.status.podIP,NODE:.spec.nodeName' \
  -w
```

---

## Quick-reference — resource short names

| Full name | Short | Example |
|-----------|-------|---------|
| `pods` | `po` | `kubectl get po` |
| `services` | `svc` | `kubectl get svc` |
| `deployments` | `deploy` | `kubectl get deploy` |
| `replicasets` | `rs` | `kubectl get rs` |
| `statefulsets` | `sts` | `kubectl get sts` |
| `daemonsets` | `ds` | `kubectl get ds` |
| `configmaps` | `cm` | `kubectl get cm` |
| `persistentvolumeclaims` | `pvc` | `kubectl get pvc` |
| `persistentvolumes` | `pv` | `kubectl get pv` |
| `namespaces` | `ns` | `kubectl get ns` |
| `nodes` | `no` | `kubectl get no` |
| `ingresses` | `ing` | `kubectl get ing` |
| `serviceaccounts` | `sa` | `kubectl get sa` |
| `horizontalpodautoscalers` | `hpa` | `kubectl get hpa` |
| `rolebindings` | `rb` | `kubectl get rb` |
| `clusterrolebindings` | `crb` | `kubectl get crb` |

---

## Aliases for your shell profile

```bash
# Add to ~/.zshrc or ~/.bashrc
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgn='kubectl get nodes -o wide'
alias kgs='kubectl get svc -A'
alias ke='kubectl get events -A --sort-by=.lastTimestamp'
alias kdp='kubectl describe pod'
alias kl='kubectl logs --tail=100 -f'
alias kns='kubectl config set-context --current --namespace'   # kns team-payments
alias kctx='kubectl config use-context'                         # kctx prod

# Current context + namespace at a glance
alias kwho='kubectl config view --minify | grep -E "name|namespace"'
```
