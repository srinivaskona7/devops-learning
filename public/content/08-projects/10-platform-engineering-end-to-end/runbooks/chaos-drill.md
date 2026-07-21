# Runbook: Chaos Drill

**Audience:** Platform engineers, SREs, senior engineers
**Frequency:** Monthly (scheduled), ad-hoc (pre-launch)
**Time to complete:** 1–3 hours
**Purpose:** Validate platform resilience and measure recovery times

---

## What a chaos drill validates

| Experiment | Hypothesis | SLO check |
|------------|------------|-----------|
| Pod kill | Kubernetes reschedules within 30s, no requests dropped | Error rate stays 0% |
| Network delay | Retries absorb delay, p95 stays within SLO | p95 within tier threshold |
| CPU stress | HPA scales out within 60s, latency recovers | p95 within tier threshold |
| Memory stress | OOM → restart → recovery within 60s | Error rate spike < 1m |
| Node drain | Workloads migrate to healthy nodes | Zero-downtime migration |

---

## Pre-drill checklist

```bash
# 1. Verify steady state (this is your baseline)
SERVICE=payment-service
NS=payment

# Error rate should be 0%
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
curl -s "http://localhost:9090/api/v1/query?query=job:http_error_rate:rate5m{job=\"$SERVICE\"}" \
  | jq '.data.result[0].value[1]'
# Expected: "0" or very close to 0

# p95 should be within SLO
curl -s "http://localhost:9090/api/v1/query?query=job:http_request_duration_p95:5m{job=\"$SERVICE\"}" \
  | jq '.data.result[0].value[1]'
# Expected: < 0.150 (gold), < 0.300 (silver), < 0.500 (bronze)

# 2. Start continuous load (do NOT stop until drill is complete)
k6 run \
  --env SERVICE_URL=https://api.vantapay.io \
  --env RATE=100 \
  --duration=15m \
  tests/k6/load.js &
K6_PID=$!
echo "k6 PID: $K6_PID"

# 3. Open Grafana in a browser — keep it visible throughout the drill
open "https://grafana.vantapay.io/d/platform-$SERVICE"

# 4. Record baseline metrics
echo "Baseline:"
echo "  Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "  p95: <value from Prometheus>"
echo "  Error rate: <value from Prometheus>"
echo "  Pod count: $(kubectl get pods -n $NS -l app=$SERVICE --no-headers | wc -l)"
```

---

## Experiment 1: Pod kill

**Hypothesis:** Killing 1 of 3 pods causes no dropped requests and recovery within 30 seconds.

```bash
# Step 1: Record which pods are running
kubectl get pods -n $NS -l app=$SERVICE

# Step 2: Apply the chaos experiment
kubectl apply -f chaos/pod-kill-experiment.yaml

# Step 3: Watch the pod be killed and rescheduled
kubectl get pods -n $NS -l app=$SERVICE --watch &
WATCH_PID=$!

# Step 4: Note the exact time of the kill
echo "Kill time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Step 5: Wait for replacement pod to be Ready
# Should take < 30 seconds

# Step 6: Stop the experiment
kubectl delete -f chaos/pod-kill-experiment.yaml

# Step 7: Record results
kill $WATCH_PID
echo "Recovery metrics:"
echo "  Time to Ready: <seconds>"
echo "  Max error rate during kill: <%>"
echo "  Max p95 during kill: <ms>"
echo "  RESULT: PASS | FAIL"
```

**Pass criteria (gold):** Error rate stayed 0%, p95 < 300ms during recovery, recovery < 30s.

---

## Experiment 2: Network delay

**Hypothesis:** 100ms network delay on 50% of packets does not cause p95 to exceed SLO.

```bash
# Step 1: Apply network delay
kubectl apply -f chaos/network-delay-experiment.yaml

echo "Delay start: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Step 2: Watch p95 in real-time via Prometheus
watch -n 5 'curl -s "http://localhost:9090/api/v1/query?query=job:http_request_duration_p95:5m{job=\"payment-service\"}" | jq ".data.result[0].value[1]"'

# Step 3: Let the experiment run for 5 minutes, then stop
sleep 300
kubectl delete -f chaos/network-delay-experiment.yaml

# Step 4: Record
echo "Network delay results:"
echo "  Peak p95: <ms>"
echo "  Error rate during experiment: <% >"
echo "  Retry rate: <% — from prometheus metric>"
echo "  RESULT: PASS | FAIL"
```

---

## Experiment 3: CPU stress

**Hypothesis:** CPU stress triggers HPA scale-out within 60 seconds, maintaining p95 within SLO.

```bash
# Step 1: Record current HPA status
kubectl get hpa -n $NS $SERVICE

# Step 2: Apply CPU stress
kubectl apply -f chaos/cpu-stress-experiment.yaml

echo "Stress start: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Step 3: Watch HPA scale-out
kubectl get hpa -n $NS $SERVICE --watch &
HPA_WATCH=$!

# Step 4: Watch CPU utilization
watch -n 10 'kubectl top pods -n $NS -l app=$SERVICE'

# Step 5: Wait for scale-out (should happen within 60s based on HPA config)
sleep 300
kubectl delete -f chaos/cpu-stress-experiment.yaml

kill $HPA_WATCH

# Step 6: Record
echo "CPU stress results:"
echo "  Time to first scale-out: <seconds>"
echo "  Final replica count: <N>"
echo "  Peak p95 during stress: <ms>"
echo "  Error rate: <% >"
echo "  RESULT: PASS | FAIL"
```

---

## Full drill: all experiments sequentially

```bash
# The Makefile target runs all experiments in sequence with load running
make chaos-drill SERVICE=payment-service TIER=gold

# Manual version:
echo "=== Starting full chaos drill ===" 
echo "Start: $(date -u)"

# Start load
k6 run --env SERVICE_URL=https://api.vantapay.io --duration=15m tests/k6/load.js &
K6_PID=$!

sleep 60  # baseline period

echo "[T+60s] Starting pod kill"
kubectl apply -f chaos/pod-kill-experiment.yaml
sleep 90

echo "[T+150s] Stopping pod kill, starting network delay"
kubectl delete -f chaos/pod-kill-experiment.yaml
kubectl apply -f chaos/network-delay-experiment.yaml
sleep 90

echo "[T+240s] Stopping network delay, starting CPU stress"
kubectl delete -f chaos/network-delay-experiment.yaml
kubectl apply -f chaos/cpu-stress-experiment.yaml
sleep 90

echo "[T+330s] Stopping CPU stress"
kubectl delete -f chaos/cpu-stress-experiment.yaml

echo "[T+330s-600s] Recovery period"
wait $K6_PID

echo "=== Drill complete ==="
echo "End: $(date -u)"
```

---

## Post-drill: generate resilience report

```bash
# Query Prometheus for drill metrics (adjust time range to drill window)
START_UNIX=<drill start time in Unix>
END_UNIX=<drill end time in Unix>

# Max p95 during drill
curl -s "http://localhost:9090/api/v1/query_range?query=job:http_request_duration_p95:5m{job=\"payment-service\"}&start=$START_UNIX&end=$END_UNIX&step=15" \
  | jq '[.data.result[0].values[] | .[1] | tonumber] | max'

# Error rate time series
curl -s "http://localhost:9090/api/v1/query_range?query=job:http_error_rate:rate5m{job=\"payment-service\"}&start=$START_UNIX&end=$END_UNIX&step=15" \
  | jq '[.data.result[0].values[] | .[1] | tonumber] | max'
```

**Resilience scorecard (fill in after drill):**

```markdown
## Chaos Drill Results — payment-service — [DATE]

| Experiment       | Recovery Time | Max p95  | Error Rate | Result |
|------------------|---------------|----------|------------|--------|
| Pod kill         | Xs            | Xms      | X%         | PASS/FAIL |
| Network delay    | N/A           | Xms      | X%         | PASS/FAIL |
| CPU stress       | Xs (HPA)      | Xms      | X%         | PASS/FAIL |

**Overall resilience score: X/100**
**SLO tier compliance: PASS/FAIL**
**Action items:** [List any failures and their remediation]
```

---

## Known failure modes and fixes

| Failure | Root cause | Fix |
|---------|-----------|-----|
| Pod kill recovery > 30s | Startup probe `initialDelaySeconds` too high | Reduce to 5s |
| CPU stress doesn't trigger HPA | HPA CPU target too high (90% instead of 60%) | Tune HPA in rollout.yaml |
| Network delay causes errors (not just latency) | No retry logic | Add Istio retry policy to VirtualService |
| Pod reschedules to same node (OOM) | TopologySpreadConstraints not configured | Add spread constraints to Rollout spec |
| k6 can't reach service during chaos | k6 running inside cluster, not outside | Run k6 from external host or kind host port |
