# Runbook: Incident Response

**Audience:** On-call engineers
**Classification:** P0 (service down), P1 (degraded), P2 (elevated errors)
**SLA:** P0 acknowledge in 5 min, mitigate in 15 min, resolve in 60 min

---

## The first 5 minutes — do these before anything else

```bash
# 1. Identify the service and namespace
SERVICE=<service-name>
NS=<namespace>

# 2. Check pod health
kubectl get pods -n $NS -l app=$SERVICE

# 3. Check rollout status — is a bad canary in progress?
kubectl argo rollouts get rollout $SERVICE -n $NS

# 4. Check recent events
kubectl get events -n $NS --sort-by='.lastTimestamp' | tail -20

# 5. Open the service dashboard
open "https://grafana.vantapay.io/d/platform-$SERVICE"
```

**If a canary is in progress and error rate is spiking: IMMEDIATELY ABORT.**

```bash
kubectl argo rollouts abort $SERVICE -n $NS
kubectl argo rollouts undo $SERVICE -n $NS
```

This is the single most impactful action in the first 5 minutes. Do not wait for confirmation.

---

## Severity classification

| Severity | Criteria | Response time | Action |
|----------|----------|---------------|--------|
| P0 | Service completely down (error rate >10%) | 5 min ack | Page entire team, executive update |
| P1 | Elevated errors (1–10%) or SLO breach | 15 min ack | Page on-call, active investigation |
| P2 | Slow burn (burn rate >1×) | 1h ack | Investigate during business hours |
| P3 | Non-SLO metric degradation | Next business day | Create Jira ticket |

---

## Diagnosis flowchart

```bash
Alert fires
    │
    ▼
Is a canary deploy in progress?
    ├── YES → Abort rollout immediately → verify rollback → monitor
    └── NO  ↓
        │
        ▼
Is error rate > threshold?
    ├── YES ─► Check recent deploys (argocd app history $SERVICE)
    │          Check pod logs (kubectl logs -n $NS -l app=$SERVICE)
    │          Check downstream dependencies (trace in Tempo)
    └── NO  ─► Check latency
               Is p95 > threshold?
                  ├── YES → Check resource saturation (HPA, CPU, memory)
                  │         Check Chaos Mesh experiments
                  └── NO  → Check availability (pod count, node health)
```

---

## Common incident scenarios

### Scenario 1: Bad deploy — error rate spike immediately after canary

**Symptoms:** Error rate alert fires 2–10 minutes after a new deployment.

```bash
# 1. Check rollout — should already be aborting if SLO gate fired
kubectl argo rollouts get rollout $SERVICE -n $NS

# 2. If not auto-aborting, manually abort:
kubectl argo rollouts abort $SERVICE -n $NS

# 3. Verify rollback completed:
kubectl argo rollouts get rollout $SERVICE -n $NS
# Status should show: Healthy with stable image

# 4. Verify error rate recovered:
# Check Grafana dashboard — error rate should drop to baseline within 2 minutes

# 5. Find the root cause — check canary pod logs:
kubectl logs -n $NS -l rollouts-pod-template-hash=$(
  kubectl get rollout $SERVICE -n $NS \
    -o jsonpath='{.status.canary.podTemplateHash}'
) --previous
```

**Communication:** Post in #incidents Slack: "P1: $SERVICE canary aborted due to elevated errors. Rolled back to stable. Investigating root cause."

### Scenario 2: Downstream dependency failure

**Symptoms:** Errors or latency spike without a recent deploy. Traces show slowness in a dependency.

```bash
# 1. Find the slow trace in Tempo (via Grafana)
# Look for: "service" > 200ms, check upstream span times

# 2. Identify the failing dependency:
kubectl get pods -n $NS
kubectl get endpoints -n $NS

# 3. Check the dependency's metrics:
kubectl top pods -n $NS

# 4. Test connectivity:
kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never -n $NS \
  -- curl -v http://<dependency-service>/healthz

# 5. Check circuit breaker status in Istio:
istioctl proxy-config clusters $SERVICE-pod-name.$NS | grep circuit
```

**Mitigation options:**
- Enable circuit breaking if not already active (check DestinationRule)
- Reduce request rate temporarily (scale down HPA)
- If dependency is Vault: existing secrets still work — ESO uses cached secret

### Scenario 3: Node failure / pod eviction

**Symptoms:** Multiple pods suddenly Terminating + Pending.

```bash
# 1. Identify affected nodes
kubectl get nodes
kubectl describe node <node-name> | grep -A5 "Conditions:"

# 2. Check pod distribution
kubectl get pods -n $NS -o wide

# 3. Kubernetes should reschedule automatically
# If not (e.g., affinity rules are too strict), manually cordon and drain:
kubectl cordon <bad-node>
kubectl drain <bad-node> --ignore-daemonsets --delete-emptydir-data

# 4. Watch pod recovery
kubectl get pods -n $NS --watch

# 5. Verify TopologySpreadConstraints allow rescheduling:
kubectl get rollout $SERVICE -n $NS -o jsonpath='{.spec.template.spec.topologySpreadConstraints}'
```

### Scenario 4: Chaos Mesh experiment running unexpectedly

**Symptoms:** Elevated latency or errors at regular intervals (daily 03:00 UTC).

```bash
# Check active chaos experiments
kubectl get podchaos,networkchaos,stresschaos -n chaos-mesh

# If experiments are running outside of expected windows, pause them:
kubectl annotate podchaos payment-service-pod-kill \
  chaos-mesh.org/pause=true -n chaos-mesh

# Or delete the experiment entirely:
kubectl delete podchaos payment-service-pod-kill -n chaos-mesh
```

### Scenario 5: Vault downtime — secret rotation failure

**Symptoms:** ExternalSecret sync failing; pods might fail to restart if secret is required.

```bash
# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# Check ESO sync errors
kubectl describe externalsecret -n $NS $SERVICE-secrets

# IMPORTANT: existing Kubernetes Secrets remain valid even if Vault is down
# Pods already running will continue to work
# Only pod restarts/new deployments will fail to get new secrets

# Emergency: if Vault is down for > 24h and ESO can't sync:
# Option A: manually patch the K8s secret with known good values
kubectl patch secret $SERVICE-secrets -n $NS \
  --type='json' \
  -p='[{"op":"replace","path":"/data/DB_PASSWORD","value":"'$(echo -n "known_good_value" | base64)'"}]'

# Option B: restore Vault from backup
# See: runbooks/rotate-secrets.md for Vault recovery procedure
```

---

## Postmortem template

Use this within 24 hours of incident resolution:

```markdown
## Incident Postmortem — [DATE] [SERVICE] P[SEVERITY]

**Duration:** [start time] – [end time] ([total duration])
**Impact:** [what users/revenue impact was, error rate, affected requests]
**Responders:** [names]

### Timeline
- HH:MM — Alert fired
- HH:MM — On-call acknowledged
- HH:MM — Root cause identified
- HH:MM — Mitigation applied
- HH:MM — Service recovered

### Root cause
[1–3 sentences describing the actual root cause, not the symptom]

### Contributing factors
- [List anything that made the incident worse or harder to diagnose]

### What went well
- [SLO gate caught the canary within X minutes]
- [Rollback was automatic]

### Action items
| Action | Owner | Due |
|--------|-------|-----|
| [Specific fix] | [Name] | [Date] |

### SLO impact
- Error budget consumed: X minutes of Y minute monthly budget
- SLO compliance this month: X.XX%
```

---

## Emergency contacts

| System | Contact | How |
|--------|---------|-----|
| Vault | Platform SRE on-call | PagerDuty: `platform-vault` |
| Argo CD | Platform team | Slack: `#platform-support` |
| Chaos Mesh | Platform SRE | Slack: `#platform-support` |
| Istio | Platform SRE | PagerDuty: `platform-mesh` |
| Registry | DevOps team | PagerDuty: `devops-infra` |
