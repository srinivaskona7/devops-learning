# Questions Bank — Interview Prep

These questions are the ones I've actually been asked / would ask in DevOps/SRE/Platform interviews at FAANG-tier and SAP-tier shops. Curated, not exhaustive — but if you can answer all of them cleanly, you're ready.

## How to use

1. **Say it out loud.** Don't read the answer first. Cover it with your hand, attempt the question verbally as if in an interview.
2. **60-second ceiling for the first pass.** If you can't give a coherent 60-second answer, you don't know it well enough.
3. **Then drill deeper.** Read the canonical answer. Identify the gap. Re-attempt 24 hours later.
4. **Pair drill.** Best results: have a peer ask the question, you answer, they push back with "why" and "what if."
5. **Whiteboard-friendly.** For Kubernetes/Terraform/Observability — sketch the architecture as you explain. Interviewers grade clarity of mental model, not memorized text.

## Study sequence

| Week | Files | Daily target |
|------|-------|--------------|
| 1 | linux.md, docker.md | 10 Q/day |
| 2 | kubernetes.md (split into 2 weeks) | 10 Q/day |
| 3 | kubernetes.md cont'd, helm.md | 10 Q/day |
| 4 | observability.md, security.md | 10 Q/day |
| 5 | terraform.md, behavioral.md | 5 Q/day + 1 STAR rehearsal |

## Self-test workflow

```bash
# Pick a random question
shuf -n 1 linux.md | grep -E '^\*\*Q'
# Time yourself: 60s answer, then read
```

## File index

| File | Count | Focus |
|------|-------|-------|
| linux.md | 50+ | Processes, FS, networking, systemd, debugging |
| docker.md | 40+ | Images, containers, networking, volumes, security |
| kubernetes.md | 80+ | Core, scheduling, networking, storage, controllers |
| helm.md | 20+ | Charts, releases, hooks, dependencies |
| observability.md | 30+ | Prometheus, Grafana, OTel, tracing, SLOs |
| security.md | 40+ | RBAC, NetworkPolicy, PSA, supply chain, secrets |
| terraform.md | 25+ | State, modules, providers, OIDC, drift |
| behavioral.md | 15+ | STAR scenarios for FAANG loops |

## Rules

- **Don't memorize verbatim.** Interviewers detect rehearsed answers immediately. Internalize the concept, then explain in your words.
- **Always state the trade-off.** "It depends" is fine if you then enumerate the variables.
- **Admit gaps cleanly.** "I haven't used X in production, but my mental model is Y" beats bluffing.
- **Lead with the answer, then justify.** Interviewers stop you when satisfied — bury the lede and you waste the slot.
