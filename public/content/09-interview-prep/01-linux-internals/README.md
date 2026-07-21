# 01 — Linux Internals

The substrate everything else runs on. If you can't explain these, you can't reason about K8s.

| File | Topic |
|------|-------|
| cgroups-v2.md | Unified hierarchy, controllers, memory.high vs memory.max |
| namespaces.md | The 8 namespaces, unshare/nsenter, user-ns mapping |
| oom-killer.md | OOM scoring, oom_score_adj, cgroup v2 OOM |
| page-cache-and-swap.md | Dirty pages, writeback, swappiness, why swap is OK in 2026 |
| networking-stack-walk.md | NIC → softirq → netfilter → socket |
| strace-and-ptrace.md | Syscall tracing in production debugging |
| systemd-internals.md | Units + cgroups, journald, socket activation |

## Why interviewers care

Senior platform roles require you to debug "why is my pod weird" at the kernel level. Cgroups + namespaces + the network stack are the load-bearing knowledge.
