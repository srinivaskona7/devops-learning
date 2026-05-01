# Kubernetes Advanced · commands quick-pick

> One-liners ordered by "what do I need when I'm paged at 03:00."
> All commands are idempotent or include teardown. Run in a kind/minikube cluster before production.

---

## Pane 1 — triage (what is broken right now?)

```bash
# All pending pods + reason
kubectl get pods -A --field-selector status.phase=Pending -o wide

# Events for the last 5 minutes, sorted newest-first
kubectl get events -A --sort-by='.lastTimestamp' | tail -40

# HPA flapping: check current vs desired replica counts
kubectl get hpa -A

# PDB blocking a drain?
kubectl get pdb -A
kubectl describe pdb <name> -n <ns>  # check "Disruptions Allowed"

# Admission webhook rejecting requests?
kubectl get events --field-selector reason=FailedCreate -A
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations

# Controller not reconciling?
kubectl logs -n <operator-ns> deploy/<operator> --tail=50 | grep -E "error|Error|ERR"
```

---

## Pane 2 — CRDs & Operators

```bash
# List all custom resource definitions
kubectl get crd

# Inspect a CRD schema (OpenAPI validation rules)
kubectl get crd <name>.group.io -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema}' | jq .

# List all CRs of a type across namespaces
kubectl get <plural> -A

# Check stored vs served versions (conversion webhook active?)
kubectl get crd <name> -o jsonpath='{.spec.versions[*].name}'

# Write controller status (use subresource — not kubectl apply)
kubectl patch <kind> <name> \
  --type=merge \
  --subresource=status \
  -p '{"status":{"phase":"Running","message":"reconciling"}}'

# Controller reconcile loop rate (operator-sdk / controller-runtime)
kubectl logs -n <ns> deploy/<controller> | grep "Reconciling" | wc -l

# Owner references — what owns this pod?
kubectl get pod <pod> -o jsonpath='{.metadata.ownerReferences}' | jq .

# Install operator-sdk (macOS/Linux)
brew install operator-sdk

# Scaffold new operator
operator-sdk init --domain example.com --repo github.com/org/my-operator
operator-sdk create api --group apps --version v1 --kind MyApp --resource --controller

# Local run (no image build)
make install && make run
```

---

## Pane 3 — HPA & VPA

```bash
# HPA status + current vs target metrics
kubectl get hpa -A
kubectl describe hpa <name>

# HPA detailed conditions (why isn't it scaling?)
kubectl get hpa <name> -o jsonpath='{.status.conditions}' | jq .

# Force HPA re-evaluate (delete and recreate — non-destructive in staging)
kubectl delete hpa <name> && kubectl apply -f hpa.yaml

# Patch HPA min/max replicas without full redeploy
kubectl patch hpa <name> --type=merge -p '{"spec":{"minReplicas":2,"maxReplicas":20}}'

# Custom metrics available? (requires Prometheus Adapter)
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq '.resources[].name'

# External metrics available? (KEDA etc.)
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1" | jq .

# VPA recommendation (no mode change required)
kubectl get vpa <name> -o jsonpath='{.status.recommendation}' | jq .
kubectl describe vpa <name>

# VPA: switch mode without restart
kubectl patch vpa <name> --type=merge -p '{"spec":{"updatePolicy":{"updateMode":"Off"}}}'

# metrics-server health
kubectl top nodes
kubectl top pods -A --sort-by=cpu | head -20
kubectl top pods -A --sort-by=memory | head -20
```

---

## Pane 4 — PodDisruptionBudgets

```bash
# Check all PDBs and disruption budget
kubectl get pdb -A

# Which pods are counted by a PDB?
kubectl get pdb <name> -o jsonpath='{.spec.selector}' | jq .
kubectl get pods -l <selector-from-above>

# Test a drain without actually draining (dry-run)
kubectl drain <node> --dry-run=client --ignore-daemonsets --delete-emptydir-data

# Live drain respecting PDBs
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --grace-period=60

# Uncordon after maintenance
kubectl uncordon <node>

# PDB blocking eviction? Force-evict one pod (override PDB — use with care)
kubectl delete pod <pod> --grace-period=0 --force

# Cluster Autoscaler respects PDBs on scale-down:
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml | grep -A5 "lastScaleDownFailTime"
```

---

## Pane 5 — Admission controllers (Kyverno / OPA)

```bash
# List all Kyverno policies
kubectl get clusterpolicy
kubectl get policy -A

# Dry-run a manifest against Kyverno policies (CI/CD pre-check)
kyverno apply ./policies/ -r ./manifests/ --policy-report

# Policy violations in the cluster right now
kubectl get policyreport -A
kubectl get clusterpolicyreport

# Detailed violation list
kubectl get policyreport <name> -o jsonpath='{.results}' | jq '.[] | select(.result=="fail")'

# OPA / Gatekeeper: list constraint templates
kubectl get constrainttemplate
kubectl get constraints

# Test OPA constraint (dry-run)
kubectl apply --dry-run=server -f bad-deployment.yaml 2>&1

# Webhook latency (check response time of webhooks)
kubectl get validatingwebhookconfigurations <name> -o jsonpath='{.webhooks[0].clientConfig}'

# Disable a webhook temporarily for emergency (restore immediately after)
kubectl patch validatingwebhookconfiguration <name> \
  --type='json' \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
# → RESTORE after emergency:
kubectl patch validatingwebhookconfiguration <name> \
  --type='json' \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Fail"}]'
```

---

## Pane 6 — Service mesh (Istio)

```bash
# Istio health check
istioctl verify-install
istioctl proxy-status          # are all sidecars in sync with control plane?

# Specific pod sidecar sync
istioctl proxy-status <pod>.<namespace>

# Debug Envoy config for a pod
istioctl proxy-config cluster  <pod> -n <ns>
istioctl proxy-config listener <pod> -n <ns>
istioctl proxy-config route    <pod> -n <ns>
istioctl proxy-config endpoint <pod> -n <ns>
istioctl proxy-config secret   <pod> -n <ns>    # mTLS certs

# Check mTLS mode
kubectl get peerauthentication -A
kubectl get peerauthentication default -n <ns> -o jsonpath='{.spec.mtls.mode}'

# Traffic split (VirtualService weights)
kubectl get virtualservice <name> -o jsonpath='{.spec.http[0].route}' | jq .

# Circuit breaker status (outlier detection)
kubectl get destinationrule <name> -o jsonpath='{.spec.trafficPolicy.outlierDetection}' | jq .

# Trace a failing request
istioctl analyze                         # scan for misconfigurations
kubectl logs <pod> -c istio-proxy | grep -E "error|upstream_reset"

# Kiali dashboard (if installed)
istioctl dashboard kiali

# Linkerd (alternative mesh)
linkerd check
linkerd top deploy/<name>
linkerd viz tap deploy/<name> --namespace <ns>
```

---

## Pane 7 — Multi-cluster (CAPI / ArgoCD)

```bash
# Cluster API: list managed clusters
kubectl get cluster -A
kubectl get machines -A
kubectl get machinedeployment -A

# Cluster status
kubectl describe cluster <name>

# Get kubeconfig for a CAPI-managed cluster
clusterctl get kubeconfig <cluster-name> > /tmp/<cluster-name>.kubeconfig
kubectl --kubeconfig /tmp/<cluster-name>.kubeconfig get nodes

# ArgoCD: list all applications across clusters
argocd app list
argocd app sync <app-name>
argocd app diff <app-name>

# ApplicationSet: list generated applications
kubectl get applicationset -n argocd
kubectl describe applicationset <name> -n argocd

# Submariner: cross-cluster connectivity check
subctl show all
subctl verify <cluster-a>.kubeconfig <cluster-b>.kubeconfig --only connectivity

# DNS: cross-cluster service discovery
# From pod in cluster-A, resolve service in cluster-B:
# nslookup <svc>.<ns>.svc.clusterset.local
```

---

## Pane 8 — StatefulSets & DB Operators

```bash
# StatefulSet status
kubectl get statefulset -A
kubectl describe statefulset <name>

# Ordered pod creation progress
kubectl get pods -l app=<name> -w

# Stable DNS for a StatefulSet pod (requires headless service)
# Format: <pod-name>.<service-name>.<namespace>.svc.cluster.local
kubectl run dns-test --image=busybox:1.28 --restart=Never -- \
  nslookup <name>-0.<headless-svc>.<ns>.svc.cluster.local
kubectl logs dns-test && kubectl delete pod dns-test

# Canary upgrade with partition
kubectl patch statefulset <name> --type=merge \
  -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'
kubectl set image statefulset/<name> <container>=<new-image>
# Only pods with ordinal >= 2 update; lower ordinals unchanged

# PVC per pod — list and check
kubectl get pvc -l app=<name>

# Force delete a stuck StatefulSet pod (it will be recreated)
kubectl delete pod <name>-2 --grace-period=0 --force

# CloudNativePG operator — postgres cluster status
kubectl get cluster -n <ns>
kubectl describe cluster <name> -n <ns>

# Strimzi Kafka — list kafka clusters
kubectl get kafka -A
kubectl get kafkatopic -A
```

---

## Pane 9 — Scheduler

```bash
# Why is a pod pending? (scheduler events)
kubectl describe pod <pod> | grep -A10 Events
kubectl get events --field-selector reason=FailedScheduling -A

# Node labels (affinity targets)
kubectl get nodes --show-labels
kubectl label node <node> disktype=ssd

# Taints on nodes
kubectl describe node <node> | grep -A5 Taints

# Add/remove taint
kubectl taint node <node> key=value:NoSchedule
kubectl taint node <node> key=value:NoSchedule-   # remove taint

# Test scheduler decision without applying
kubectl apply --dry-run=server -f pod.yaml 2>&1 | grep -E "scheduled|error"

# TopologySpreadConstraints — check actual spread
kubectl get pods -l app=<name> -o json | \
  jq '[.items[] | {pod: .metadata.name, node: .spec.nodeName, zone: .spec.nodeSelector["topology.kubernetes.io/zone"]}]'

# Node allocatable vs requested
kubectl describe node <node> | grep -A20 "Allocated resources"

# All pod resource requests on a node
kubectl describe node <node> | grep -E "cpu|memory" | head -20

# Preemption events (low-priority pods evicted for high-priority)
kubectl get events --field-selector reason=Preempting -A
```

---

## Pane 10 — CNI & eBPF (Cilium)

```bash
# Cilium status (overall health)
cilium status --wait
# OR without cilium CLI:
kubectl -n kube-system exec ds/cilium -- cilium status

# BPF service map (replaces iptables NAT)
kubectl -n kube-system exec ds/cilium -- cilium bpf lb list

# BPF network policy map
kubectl -n kube-system exec ds/cilium -- cilium bpf policy list

# Endpoint list (all pods Cilium knows about)
kubectl -n kube-system exec ds/cilium -- cilium endpoint list

# Packet drop reasons (network policy blocking?)
kubectl -n kube-system exec ds/cilium -- cilium monitor --type drop

# Hubble flow visibility (requires hubble-relay)
hubble observe --namespace <ns> --follow
hubble observe --verdict DROPPED

# Connectivity test (pod-to-pod and pod-to-service)
cilium connectivity test

# iptables rules count (should be ~0 on kube-proxy-free Cilium)
kubectl -n kube-system exec ds/cilium -- iptables -L -n | wc -l

# CNI plugin binary location (non-Cilium debugging)
ls /opt/cni/bin/
cat /etc/cni/net.d/*.conflist

# Network policy dry-run with Cilium
kubectl apply --dry-run=server -f networkpolicy.yaml

# Verify no kube-proxy running (Cilium replacement mode)
kubectl get pods -n kube-system | grep kube-proxy   # should be empty
```

---

## Pane 11 — Feature gates & changelog

```bash
# Current API server feature gates
kubectl get configmap -n kube-system kubeadm-config -o yaml | grep featureGates
# OR check API server flags:
kubectl -n kube-system get pod kube-apiserver-<node> -o yaml | grep feature-gates

# All Kubernetes API resources + versions (spot removed/added APIs)
kubectl api-resources --verbs=list -o wide
kubectl api-versions | sort

# Deprecated API usage scan
kubectl api-resources --verbs=list -o name | xargs -I{} kubectl get {} -A 2>/dev/null | grep -v "No resources"

# In-place pod resize (1.32 stable)
kubectl patch pod <pod> --type=merge -p \
  '{"spec":{"containers":[{"name":"<container>","resources":{"limits":{"cpu":"500m"}}}]}}'
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].resources}' | jq .

# Sidecar container check (1.29+ beta)
kubectl get pod <pod> -o jsonpath='{.spec.initContainers}' | \
  jq '.[] | select(.restartPolicy=="Always")'

# Check kubelet version on all nodes (version skew policy)
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}: {.status.nodeInfo.kubeletVersion}{"\n"}{end}'

# Find feature gates enabled in kubelet
kubectl -n kube-system get configmap kubelet-config -o yaml | grep -A5 featureGates

# Which PodSecurityPolicy objects remain? (removed in 1.25)
kubectl get psp 2>&1   # should return: error: the server doesn't have a resource type "podsecuritypolicies"

# Pod Security Admission (PSA) — check namespace labels
kubectl get namespace -o json | jq '.items[] | {name: .metadata.name, labels: .metadata.labels}' | \
  jq 'select(.labels["pod-security.kubernetes.io/enforce"] != null)'
```

---

## Pane 12 — Cluster-wide health checks

```bash
# Control plane component health
kubectl get componentstatuses   # deprecated but still works on kubeadm clusters
kubectl get pods -n kube-system

# etcd health (kubeadm clusters)
kubectl -n kube-system exec etcd-<node> -- \
  etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# etcd member list
kubectl -n kube-system exec etcd-<node> -- \
  etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --write-out=table

# Node conditions (disk pressure, memory pressure, PID pressure)
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, conditions: [.status.conditions[] | select(.status=="True")]}'

# Pod restarts sorted (leak detector)
kubectl get pods -A --sort-by='.status.containerStatuses[0].restartCount' | tail -20

# Resource quota usage per namespace
kubectl get resourcequota -A
kubectl describe resourcequota -n <ns>

# LimitRange in namespace (affects VPA interactions)
kubectl get limitrange -A
kubectl describe limitrange -n <ns>

# Certificate expiry (kubeadm clusters)
kubeadm certs check-expiration

# Audit log tail (if audit logging enabled)
tail -f /var/log/kubernetes/audit.log | jq 'select(.verb=="create") | {user: .user.username, resource: .objectRef.resource, name: .objectRef.name}'
```

---

## Quick-reference: tool install one-liners

```bash
# operator-sdk
brew install operator-sdk                                        # macOS
curl -sLO https://github.com/operator-framework/operator-sdk/releases/latest/download/operator-sdk_linux_amd64
chmod +x operator-sdk_linux_amd64 && mv operator-sdk_linux_amd64 /usr/local/bin/operator-sdk

# clusterctl (CAPI)
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/latest/download/clusterctl-linux-amd64 \
  -o /usr/local/bin/clusterctl && chmod +x /usr/local/bin/clusterctl

# istioctl
curl -L https://istio.io/downloadIstio | sh -
export PATH="$PATH:$(ls -d $HOME/istio-*/bin)"

# cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz"
tar xzvf cilium-linux-amd64.tar.gz -C /usr/local/bin
rm cilium-linux-amd64.tar.gz

# hubble CLI (Cilium observability)
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-amd64.tar.gz"
tar xzvf hubble-linux-amd64.tar.gz -C /usr/local/bin

# kyverno CLI
brew install kyverno                                             # macOS
# Linux:
curl -LO https://github.com/kyverno/kyverno/releases/latest/download/kyverno-cli_linux_x86_64.tar.gz
tar -xvf kyverno-cli_linux_x86_64.tar.gz && mv kyverno /usr/local/bin/

# subctl (Submariner)
curl -Ls https://get.submariner.io | bash

# argocd CLI
brew install argocd                                              # macOS
# Linux:
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd-linux-amd64 && mv argocd-linux-amd64 /usr/local/bin/argocd
```
