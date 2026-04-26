# 11 — Troubleshooting Deep Dive

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-03-advanced-11-troubleshooting-deep-dive-README-1-f85db80e.svg" alt="diagram" / loading="lazy"></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart TD
    Sym[Symptom] --> Class{Classify}
    Class -->|pod not starting| Img[ImagePullBackOff\nErrImagePull]
    Class -->|pod restarting| CLB[CrashLoopBackOff]
    Class -->|killed| OOM[OOMKilled\nexit 137]
    Class -->|stuck| Pending[Pending\nUnschedulable]
    Class -->|networking| Net[DNS / Service / NetworkPolicy]
    Img --> Reg[registry creds, image tag, pull policy]
    CLB --> Logs[kubectl logs --previous]
    OOM --> Lim[increase memory limit OR fix leak]
    Pending --> Sch[describe pod -> scheduling events]
    Net --> Probe[kubectl debug + nslookup, curl]
```

</details>
## Quick reference

=== ":material-lightbulb-outline: Concept"
    Triage starts with classifying the symptom (ImagePullBackOff, CrashLoop, OOMKilled, Pending, networking) then drilling into events and previous-container logs. Ephemeral containers (`kubectl debug`) attach a debugging toolbox to a running pod without rebuilding the image.

=== ":material-file-code-outline: Manifest"
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: netshoot
      labels: { app: netshoot }
    spec:
      containers:
        - name: netshoot
          image: nicolaka/netshoot:latest
          command: ["sleep", "infinity"]
          securityContext:
            capabilities:
              add: ["NET_ADMIN", "NET_RAW"]
      restartPolicy: Always
    ```

=== ":material-console: kubectl"
    ```bash
    kubectl get events --sort-by=.lastTimestamp -A | tail -20
    kubectl describe pod <pod>
    kubectl logs <pod> --previous
    kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container>
    kubectl debug node/<node> -it --image=busybox
    kubectl top pod
    ```

=== ":material-text-box-outline: Expected output"
    ```text
    LAST SEEN   TYPE      REASON             OBJECT             MESSAGE
    32s         Warning   BackOff            pod/api-7d-abcde   Back-off restarting failed container
    20s         Warning   Unhealthy          pod/api-7d-abcde   Readiness probe failed: HTTP 503
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
    ```

## Tooling

| Need | Command |
|------|---------|
| Inject a debug container into a running pod | `kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container>` |
| Debug a node (privileged pod on the host) | `kubectl debug node/<node> -it --image=busybox` |
| Copy a pod for tweaking | `kubectl debug <pod> --copy-to=debug --container=<c> --set-image=<c>=busybox -- sh` |
| Previous container logs | `kubectl logs <pod> --previous` |
| Recent events | `kubectl get events --sort-by=.lastTimestamp -A` |
| Live resource usage | `kubectl top pod` / `kubectl top node` |
| Profile control plane | `kubectl get --raw /debug/pprof/heap > heap.out` (with custom profiling endpoints) |
| Audit log | apiserver `--audit-policy-file` + `--audit-log-path` |

## Ephemeral containers
- Added by `kubectl debug` against a running pod.
- Share the pod's PID and network namespace via `--target=<container>` (so you can `nsenter`-like inspect the target's process).
- Cannot be removed — they live for the pod's lifetime.

## Root-cause cheatsheet

| Symptom | Common root causes |
|---------|--------------------|
| **ImagePullBackOff / ErrImagePull** | Wrong image:tag, private registry without imagePullSecret, rate-limited (Docker Hub anonymous), `imagePullPolicy: Always` against an offline registry |
| **CrashLoopBackOff** | App crashes on startup (config, missing secret), failing readiness/liveness probe, exit code != 0, missing volume |
| **OOMKilled (exit 137)** | Memory limit too low, leak, JVM/Node heap not aligned with cgroup limit |
| **Pending / Unschedulable** | No node has resources, taint without matching toleration, `nodeSelector` / affinity does not match, PVC pending (no provisioner) |
| **Init:CrashLoopBackOff** | Init container failing — check its logs explicitly with `-c <init-name>` |
| **Terminating forever** | Finalizer left by a controller that no longer exists — `kubectl patch ... -p '{"metadata":{"finalizers":null}}'` |
| **DNS NXDOMAIN inside pod** | CoreDNS down, NetworkPolicy blocking egress to kube-dns, wrong `dnsPolicy` |
| **Service has no endpoints** | Selector typo, all pods Not Ready, headless without subdomain set |

## Audit logs
```yaml
# audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets","configmaps"]
  - level: RequestResponse
    verbs: ["create","update","patch","delete"]
    resources:
      - group: "rbac.authorization.k8s.io"
```

## Files
- [debug-pod.yaml](debug-pod.yaml)
