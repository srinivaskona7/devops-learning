# Troubleshooting Deep Dive — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
kubectl get nodes
```

## Apply manifests

```bash
kubectl apply -f debug-pod.yaml
```

## First-pass triage

```bash
kubectl get pods -A | grep -vE 'Running|Completed'
kubectl get events -A --sort-by=.lastTimestamp | tail -30
kubectl get nodes -o wide
kubectl top nodes
kubectl top pods -A --sort-by=memory | head -20
kubectl top pods -A --sort-by=cpu    | head -20
```

## Inspect a single pod

```bash
kubectl describe pod <pod>                          # events at the bottom
kubectl get pod <pod> -o yaml | head -80
kubectl logs <pod>                                  # current container
kubectl logs <pod> --previous                       # last crash output
kubectl logs <pod> -c <container>
kubectl logs <pod> --all-containers=true --tail=200
kubectl logs -f <pod>
```

## Ephemeral debug containers

```bash
# Inject a debug toolbox alongside a running pod (shares PID/net via --target)
kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container>

# Debug a node (privileged pod on the host)
kubectl debug node/<node> -it --image=busybox

# Copy a pod for tweaking (keeps original running)
kubectl debug <pod> --copy-to=debug --container=<c> --set-image=<c>=busybox -- sh
```

## Networking sanity

```bash
# DNS
kubectl run dns-test --rm -it --image=busybox --restart=Never -- \
  nslookup kubernetes.default

# Service connectivity
kubectl run curl --rm -it --image=curlimages/curl --restart=Never -- \
  curl -v http://<svc>.<ns>.svc.cluster.local/

# Endpoints behind a Service
kubectl get endpoints <svc>
kubectl get endpointslices -l kubernetes.io/service-name=<svc>

# NetworkPolicy in effect
kubectl get netpol -A
kubectl describe netpol <name>
```

## Resource pressure

```bash
kubectl describe node <node> | grep -A5 -E 'Conditions|Allocatable|Allocated'
kubectl get pods -A --field-selector spec.nodeName=<node>
kubectl top pod --sort-by=memory -A | head -20
```

## Symptom → first-look commands

| Symptom | Commands |
|---------|----------|
| **ImagePullBackOff** | `kubectl describe pod <p>` ; check secret `kubectl get sa <sa> -o yaml` ; pull manually `docker pull <image>` |
| **CrashLoopBackOff** | `kubectl logs <p> --previous` ; `kubectl describe pod <p>` |
| **OOMKilled (137)** | `kubectl describe pod <p>` ; raise `resources.limits.memory`; check leaks |
| **Pending / Unschedulable** | `kubectl describe pod <p>` ; `kubectl get nodes -o wide` ; `kubectl get pvc <p>` |
| **Init:CrashLoopBackOff** | `kubectl logs <p> -c <init-name> --previous` |
| **Terminating forever** | `kubectl get <kind> <name> -o yaml` (finalizers) ; `kubectl patch ... -p '{"metadata":{"finalizers":null}}'` |
| **DNS NXDOMAIN** | `kubectl -n kube-system get pods -l k8s-app=kube-dns` ; nslookup test ; check NetworkPolicy egress |
| **Service has no endpoints** | `kubectl get endpoints <svc>` ; check selector vs pod labels ; pod `Ready` status |

## Audit log (apiserver)

```bash
# audit-policy.yaml example
cat > audit-policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
  - level: Metadata
    resources:
      - { group: "", resources: ["secrets","configmaps"] }
  - level: RequestResponse
    verbs: ["create","update","patch","delete"]
    resources:
      - { group: "rbac.authorization.k8s.io" }
EOF

# Wire into apiserver --audit-policy-file + --audit-log-path
```

## Cleanup

```bash
kubectl delete -f debug-pod.yaml --ignore-not-found
```

## One-liners worth memorising

```bash
kubectl get events -A --sort-by=.lastTimestamp | tail -30
kubectl describe pod <pod>
kubectl logs <pod> --previous
kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container>
kubectl debug node/<node> -it --image=busybox
kubectl get endpoints <svc>
kubectl top pods -A --sort-by=memory | head -20
kubectl patch <kind> <name> --type=merge -p '{"metadata":{"finalizers":null}}'
```
