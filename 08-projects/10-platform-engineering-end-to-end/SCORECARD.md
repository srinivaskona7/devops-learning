# Platform Maturity Scorecard

**Model:** Team Topologies-inspired capability maturity (1–4 scale)
**Version:** 1.0
**Assessment date:** _(fill in after each sprint review)_
**Assessors:** Platform team + one representative from each stream-aligned team

---

## Scoring scale

| Score | Label | Meaning |
|-------|-------|---------|
| 1 | Initial | Ad-hoc, manual, no standards |
| 2 | Managed | Documented, partially automated, inconsistent adoption |
| 3 | Defined | Standardized, automated, consistently adopted |
| 4 | Optimizing | Self-healing, continuously improving, measured |

---

## Capability 1: Discovery & Onboarding

_Can a new engineer find what they need and onboard a service in < 1 day?_

| Dimension | Score | Evidence | Gap to next level |
|-----------|-------|----------|------------------|
| Service catalog | \_/4 | Backstage catalog populated? | All services registered = 3; auto-registration = 4 |
| Documentation | \_/4 | Runbooks exist and tested? | Exists = 2; tested quarterly = 3; self-updating = 4 |
| Golden path | \_/4 | Template exists and used? | Template exists = 2; <30min onboard = 3; <10min = 4 |
| Search | \_/4 | Can engineers find APIs and owners? | Backstage search works = 3; semantic search = 4 |
| **Capability total** | **\_/16** | | |

**Target state:** Demonstrate that a new engineer can onboard a new service from zero to first production deploy in under 30 minutes using only the golden-path template and this scorecard.

---

## Capability 2: Development Experience

_Does the platform accelerate rather than block development?_

| Dimension | Score | Evidence | Gap to next level |
|-----------|-------|----------|------------------|
| Local dev speed | \_/4 | Time from code change to local test? | < 5 min = 3; < 1 min hot reload = 4 |
| CI speed | \_/4 | Time from push to green CI? | < 15 min = 3; < 5 min = 4 |
| Test coverage | \_/4 | Unit + integration + E2E automated? | 70% coverage = 2; 85% + mutation = 3; 95% + chaos = 4 |
| Code review | \_/4 | Automated checks before human review? | Linting = 2; security scan = 3; AI review = 4 |
| Policy compliance | \_/4 | Kyverno violations caught before deploy? | Admission-time = 3; pre-commit + admission = 4 |
| **Capability total** | **\_/20** | | |

---

## Capability 3: Delivery

_Can teams deploy to production confidently and frequently?_

| Dimension | Score | Evidence | Gap to next level |
|-----------|-------|----------|------------------|
| Deploy frequency | \_/4 | How often do teams deploy? | Weekly = 2; daily = 3; multiple/day = 4 |
| Deploy safety | \_/4 | Canary + automatic rollback? | Manual canary = 2; auto SLO gate = 3; multi-stage progressive = 4 |
| Rollback speed | \_/4 | Time to rollback on incident? | < 10 min manual = 2; < 2 min automated = 3; < 30s = 4 |
| GitOps adoption | \_/4 | All services deployed via GitOps? | Some services = 2; all services = 3; policy enforced = 4 |
| Change failure rate | \_/4 | % of deployments causing incidents | < 15% = 2; < 5% = 3; < 1% = 4 |
| **Capability total** | **\_/20** | | |

**DORA targets for level 4:**
- Deploy frequency: multiple times per day per service
- Lead time for changes: < 1 hour
- Change failure rate: < 1%
- Time to restore: < 5 minutes

---

## Capability 4: Observability

_Can engineers diagnose any issue in < 15 minutes using platform tools?_

| Dimension | Score | Evidence | Gap to next level |
|-----------|-------|----------|------------------|
| Metrics coverage | \_/4 | All services have RED metrics? | Some = 2; all services = 3; custom business metrics too = 4 |
| Log aggregation | \_/4 | All logs in Loki, structured? | Some = 2; all + structured = 3; correlated to traces = 4 |
| Distributed tracing | \_/4 | Traces across all service hops? | Some services = 2; all services = 3; auto-instrumented = 4 |
| Alerting | \_/4 | SLO-based burn rate alerts? | Symptom alerts = 2; SLO burn rate = 3; ML anomaly detection = 4 |
| Dashboards | \_/4 | Auto-provisioned per service? | Manual = 1; template = 3; auto-generated from code = 4 |
| MTTR | \_/4 | Mean time to resolve incidents? | < 60 min = 2; < 15 min = 3; < 5 min = 4 |
| **Capability total** | **\_/24** | | |

**MTTR test:** Pick a random past incident. Can a new engineer reproduce the diagnosis in < 15 minutes using only Grafana and the runbooks?

---

## Capability 5: Reliability

_Does the platform enforce reliability standards automatically?_

| Dimension | Score | Evidence | Gap to next level |
|-----------|-------|----------|------------------|
| SLO definition | \_/4 | All services have SLOs? | Some = 2; all = 3; tiered with business alignment = 4 |
| Error budget | \_/4 | Error budgets tracked and enforced? | Tracked = 2; freeze policy when exhausted = 3; auto-throttle deploys = 4 |
| Chaos engineering | \_/4 | Regular chaos experiments? | Ad-hoc = 1; monthly = 2; automated in CI = 3; continuous = 4 |
| Resilience score | \_/4 | Services have measurable resilience scores? | None = 1; manual assessment = 2; automated score = 3; gated = 4 |
| Incident process | \_/4 | Runbooks tested and followed? | Exists = 2; tested quarterly = 3; automated steps = 4 |
| **Capability total** | **\_/20** | | |

---

## Capability 6: Security

_Is security enforced by the platform, not by individual team diligence?_

| Dimension | Score | Evidence | Gap to next level |
|-----------|-------|----------|------------------|
| Secret management | \_/4 | Secrets in Vault, auto-rotated? | Not in git = 2; Vault + ESO = 3; dynamic secrets, 24h lease = 4 |
| Image supply chain | \_/4 | All images signed and attested? | No signing = 1; signed = 3; SBOM + vuln attest = 4 |
| Admission control | \_/4 | Policies enforced at admission? | Some = 2; all 5 policies Enforce = 3; custom policies per team = 4 |
| Network security | \_/4 | mTLS everywhere? | Some namespaces = 2; all namespaces STRICT = 3; AuthzPolicy per service = 4 |
| Vulnerability management | \_/4 | CVEs in images managed? | Manual scan = 2; CI gate + auto-PR = 3; SBOMs + drift detection = 4 |
| Audit trail | \_/4 | All platform changes auditable? | Git history = 2; Argo CD audit log = 3; SIEM integration = 4 |
| **Capability total** | **\_/24** | | |

---

## Overall platform maturity score

| Capability | Score | Max | % |
|------------|-------|-----|---|
| Discovery & Onboarding | \_\_\_ | 16 | \_\_\_% |
| Development Experience | \_\_\_ | 20 | \_\_\_% |
| Delivery | \_\_\_ | 20 | \_\_\_% |
| Observability | \_\_\_ | 24 | \_\_\_% |
| Reliability | \_\_\_ | 20 | \_\_\_% |
| Security | \_\_\_ | 24 | \_\_\_% |
| **TOTAL** | **\_\_\_** | **124** | **\_\_\_%** |

---

## Target maturity by quarter

| Quarter | Target score | Key capabilities to advance |
|---------|-----------|-----------------------------|
| Q1 2026 (now) | 60/124 (48%) | Bootstrap platform, all services onboarded |
| Q2 2026 | 80/124 (65%) | SLO error budgets live, chaos automated |
| Q3 2026 | 100/124 (81%) | Dynamic secrets, auto-provisioned dashboards |
| Q4 2026 | 115/124 (93%) | Continuous chaos, DORA metrics tracked |

---

## Assessment notes

_Fill in during quarterly review:_

**What's working well:**

**What needs improvement:**

**Blockers:**

**Action items for next quarter:**

| Action | Owner | Target | Status |
|--------|-------|--------|--------|
| | | | |
