# Post-Incident Review — Blameless Postmortem Template

**Incident ID:** INC-YYYY-MM-DD-NNN  
**Date of incident:** YYYY-MM-DD  
**Date of postmortem:** YYYY-MM-DD (within 48 hours of resolution)  
**Facilitator:** [Name — should not be the on-call engineer who worked the incident]  
**Scribe:** [Name]  
**Attendees:** [List all participants; include stakeholders, not just engineers]

---

> **Blameless culture principle:**
> This document exists to understand what happened and improve systems —
> not to assign blame. People act rationally given the information and tools
> available to them at the time. The goal is to make the system more resilient,
> not to penalize the human closest to the failure.

---

## 1 — Executive summary

*Write this section LAST, after the full analysis is complete. Keep to 3-5 sentences.*

On [date], [what failed] resulted in [customer impact] for approximately [duration].
The root cause was [one sentence].
The incident was detected by [detection mechanism] at [time], and resolved at [time].
RTO was [X minutes] — [within/exceeding] the [15-minute] target.
Data loss was [none / Y seconds / Y rows] — [within/exceeding] the RPO target of 30 seconds.

---

## 2 — Impact

| Metric | Value |
|--------|-------|
| Start time | |
| End time | |
| Duration | |
| Affected users | |
| Affected requests | |
| Error rate peak | |
| Data loss | |
| RTO achieved | |
| RPO achieved | |
| SLO impact | |
| Customer support tickets | |

---

## 3 — Timeline

*Use UTC timestamps. Include every action taken — including failed attempts.  
Actions by automated systems are included alongside human actions.*

| Time (UTC) | Event | Source | Notes |
|-----------|-------|--------|-------|
| T-00:00 | [Describe what failed — the trigger] | [system/human] | |
| T+01:23 | [Detection: alarm fired] | CloudWatch | |
| T+02:45 | [On-call acknowledged PagerDuty] | Human | |
| T+03:10 | [On-call confirmed region loss via kubectl] | Human | |
| T+04:00 | [Stakeholders notified in #incidents] | Human | |
| T+05:30 | [WAL lag measured: X seconds] | Human | |
| T+06:00 | [Velero restore started] | Automated | |
| T+08:00 | [Postgres promoted to primary in secondary region] | Human | |
| T+10:30 | [Smoke test passed on secondary] | Automated | |
| T+11:00 | [DNS TTL lowered to 60s] | Human | |
| T+11:15 | [DNS cutover executed] | Human | |
| T+13:00 | [DNS propagation confirmed] | Automated dig loop | |
| T+13:45 | [Error rate returned to < 0.1%] | CloudWatch | |
| T+14:00 | [Incident declared resolved] | Human | |

---

## 4 — Root cause analysis

### 4.1 — What happened (technical narrative)

*Describe the failure in technical detail. Include system states, data flows,
and the sequence of events that led to user impact. Be specific.*

[Narrative here]

### 4.2 — Five Whys

Use the Five Whys method to drill down to the systemic root cause.
Stop when you reach a system or process issue — not a human mistake.

| Why # | Question | Answer |
|-------|----------|--------|
| Why 1 | Why did users experience errors? | [answer] |
| Why 2 | Why did [answer to Why 1] happen? | [answer] |
| Why 3 | Why did [answer to Why 2] happen? | [answer] |
| Why 4 | Why did [answer to Why 3] happen? | [answer] |
| Why 5 | Why did [answer to Why 4] happen? | **Root cause** |

**Root cause statement:**
> [One sentence: the systemic condition that, if fixed, prevents this class of incident]

### 4.3 — Contributing factors

*List conditions that made the failure more likely or more severe.
These are not root causes but are important to address.*

- **Factor 1:** [describe]
- **Factor 2:** [describe]
- **Factor 3:** [describe]

### 4.4 — What went well

*Document what worked — systems, processes, and human decisions that
limited the impact or accelerated recovery. These practices should be
reinforced, not forgotten.*

- [What worked 1]
- [What worked 2]
- [What worked 3]

### 4.5 — What could have gone better

*Honest assessment of gaps — detection gaps, tooling gaps, process gaps,
knowledge gaps. No blame; only system observations.*

- [Gap 1]
- [Gap 2]
- [Gap 3]

---

## 5 — Detection analysis

*Analyze how the incident was detected and how detection could be improved.*

| Question | Answer |
|----------|--------|
| How was the incident first detected? | |
| Was detection automatic or human-triggered? | |
| How long between failure start and detection? | |
| What alert fired first? | |
| Were there earlier signals that were missed? | |
| What is the ideal detection time for this failure mode? | |

**Detection gap analysis:**

If the first detection was human-triggered:
- What monitoring would have caught this automatically?
- Add that monitoring as an action item.

If the alert fired but was ignored or delayed:
- Was the alert well-described?
- Was the on-call engineer properly trained?
- Was there alert fatigue from too many false positives?

---

## 6 — DR system performance

*Evaluate how the DR infrastructure performed during this incident.*

### Velero restore

| Metric | Target | Actual | Pass? |
|--------|--------|--------|-------|
| Backup available in secondary BSL | Within 75s of backup creation | | |
| Restore start time from decision | < 2 min | | |
| Restore completion time | < 6 min | | |
| Restore errors | 0 | | |
| Objects restored count | [expected] | | |

### WAL-G Postgres PITR

| Metric | Target | Actual | Pass? |
|--------|--------|--------|-------|
| WAL lag at failover | ≤ 30 s | | |
| Postgres promotion time | < 2 min | | |
| PITR restore accuracy | Correct timestamp | | |
| Data row count (post-restore vs expected) | Match | | |

### DNS failover

| Metric | Target | Actual | Pass? |
|--------|--------|--------|-------|
| TTL at time of failover | ≤ 60 s | | |
| Health check failure detection | ≤ 30 s | | |
| Route53 record switch | ≤ 60 s after detection | | |
| DNS propagation to 95% of clients | ≤ 90 s | | |

### Overall DR metrics

| Metric | Target | Actual | Pass? |
|--------|--------|--------|-------|
| RTO | ≤ 15 min | | |
| RPO | ≤ 30 s | | |
| Data integrity (SHA-256) | Match | | |

---

## 7 — Action items

*Every action item must have: owner, due date, and a success criterion.
No action item should be "investigate" without a follow-up deliverable.
Track these in your issue tracker.*

| # | Action | Owner | Due | Priority | Issue link | Success criterion |
|---|--------|-------|-----|----------|-----------|-------------------|
| 1 | | | | P1 | | |
| 2 | | | | P2 | | |
| 3 | | | | P2 | | |
| 4 | | | | P3 | | |

### Action item categories

When generating action items, check each category:

**Detection:**
- [ ] New CloudWatch alarm for [gap identified in Section 5]
- [ ] Dashboard panel for [metric that was manually checked]
- [ ] Runbook link from alert to specific step

**Prevention:**
- [ ] Code/config change to eliminate root cause
- [ ] Architecture change to reduce blast radius

**DR system improvements:**
- [ ] Runbook update (which steps were unclear or wrong?)
- [ ] Automation for manual steps that exceeded time budget
- [ ] Test coverage for this failure mode in next drill

**Communication:**
- [ ] Status page automation
- [ ] Customer communication template
- [ ] Internal escalation contact list update

---

## 8 — Runbook review

*Did this runbook help or hinder the response?*

| Step | Was it followed? | Any issues? | Proposed change |
|------|-----------------|-------------|-----------------|
| Step 1 — Declare incident | | | |
| Step 2 — Confirm region loss | | | |
| Step 3 — Measure WAL lag | | | |
| Step 4 — Lower DNS TTL | | | |
| Step 5 — Velero restore | | | |
| Step 6 — Promote Postgres | | | |
| Step 7 — Update connection string | | | |
| Step 8 — Verify restore | | | |
| Step 9 — Smoke test | | | |
| Step 10 — DNS cutover | | | |
| Step 11 — Monitor error rate | | | |
| Step 12 — Verify RTO | | | |
| Step 13 — Notify stakeholders | | | |
| Step 14 — Monitor | | | |
| Step 15 — Failback assessment | | | |

**Runbook update owner:** [Name]  
**Runbook update due:** [Date — within 1 week of postmortem]

---

## 9 — Next quarterly drill updates

*Based on this incident, what should be added or changed in the next DR drill?*

- [ ] Add scenario: [this failure mode]
- [ ] Test detection time for: [gap identified]
- [ ] Validate that action item [#N] from this postmortem is effective

---

## Document sign-off

| Role | Name | Sign-off date |
|------|------|--------------|
| Incident facilitator | | |
| Engineering lead | | |
| SRE lead | | |
| Engineering director | | |

---

*Template version: 2026-01-01. Update after each incident review cycle.*
