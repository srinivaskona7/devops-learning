# Runtime Security — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# Falco (eBPF driver, recommended on modern kernels)
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  -n falco --create-namespace \
  --set driver.kind=modern_ebpf \
  --set tty=true \
  --set falcosidekick.enabled=true

# Tetragon (Cilium / Isovalent)
helm repo add cilium https://helm.cilium.io
helm install tetragon cilium/tetragon -n kube-system

# Tracee (Aqua)
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm install tracee aqua/tracee -n tracee --create-namespace
```

## Apply policies / manifests

```bash
# Falco custom rules
kubectl apply -f falco-rules.yaml
kubectl rollout restart daemonset/falco -n falco

# Tetragon TracingPolicy (detect + optionally block)
kubectl apply -f tetragon-policy.yaml

# Falcosidekick → Slack/PagerDuty/SIEM (set webhook env)
kubectl set env -n falco deploy/falco-falcosidekick \
  SLACK_WEBHOOKURL=https://hooks.slack.com/services/...
```

## Inspect / verify

```bash
# Tail Falco events live
kubectl logs -n falco -l app.kubernetes.io/name=falco -f

# Trigger a rule on purpose — shell in container
kubectl run shell-test --image=alpine -it --rm -- sh -c "cat /etc/shadow; exit"

# Tetragon event stream (eBPF observed)
kubectl exec -n kube-system ds/tetragon -c tetragon -- \
  tetra getevents -o compact

# Filter Tetragon events to a namespace
kubectl exec -n kube-system ds/tetragon -c tetragon -- \
  tetra getevents --namespace prod

# Falcosidekick UI
kubectl port-forward -n falco svc/falco-falcosidekick-ui 2802:2802

# Check the loaded rule set
kubectl exec -n falco ds/falco -- falco --list
kubectl exec -n falco ds/falco -- falco --validate /etc/falco/falco_rules.yaml
```

## Common operations

```bash
# Reload rules without restart (Falco supports SIGHUP)
kubectl exec -n falco ds/falco -- killall -HUP falco

# Dry-run new rule (output only, don't enforce sidekick fanout)
kubectl set env -n falco ds/falco FALCO_DRY_RUN=true

# Tetragon: enforce mode (kill matching process via SIGKILL)
# Add `enforce: true` and selectors.matchActions.action: Sigkill in TracingPolicy

# Forward Falco events to S3 via sidekick
kubectl set env -n falco deploy/falco-falcosidekick \
  AWS_S3_BUCKET=falco-events AWS_S3_REGION=us-east-1
```

## Cleanup

```bash
kubectl delete -f falco-rules.yaml
kubectl delete -f tetragon-policy.yaml
helm uninstall falco -n falco
helm uninstall tetragon -n kube-system
helm uninstall tracee -n tracee
kubectl delete ns falco tracee
```

## One-liners worth memorising

```bash
# Trigger a sensitive-file-read alert on purpose (test ruleset)
kubectl exec -it <pod> -- cat /etc/shadow

# Count rule-fire frequency over last hour
kubectl logs -n falco ds/falco --since=1h \
  | grep -oP 'Rule: [^"]+' | sort | uniq -c | sort -rn

# List every container drift (process not in original image)
kubectl exec -n kube-system ds/tetragon -c tetragon -- tetra getevents \
  --event-types PROCESS_EXEC | jq 'select(.process_exec.process.binary | test("^/tmp"))'

# Forward all events to stdout for SIEM scrape
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=-1 -f
```
