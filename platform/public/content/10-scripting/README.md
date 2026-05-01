# 10 · Scripting Automations — Python & Bash

<div class="ambient"></div>

> **Stop clicking. Start scripting.**  
> From your first `#!/usr/bin/env bash` to a composable Python DAG that orchestrates infrastructure — this module covers the full scripting arc used by production engineering teams.

---

## Learning Path

```mermaid
flowchart LR
    A["Shell Survival<br/>set -euo pipefail"] --> B["Bash Fundamentals<br/>vars, loops, functions"]
    B --> C["Bash Automation<br/>traps, getopts, xargs"]
    C --> D["Bash Expert<br/>FIFOs, daemons, DSLs"]
    D --> E["Python Foundations<br/>subprocess, pathlib"]
    E --> F["Python CLI Tools<br/>click, requests, pydantic"]
    F --> G["Python DevOps Libs<br/>boto3, k8s, docker SDK"]
    G --> H["Meta-Automation<br/>DAG pipelines, kopf"]
```

---

## Module Roadmap

<div class="roadmap" markdown>

<div class="stop" data-step="1" markdown>
#### Shell Survival Kit
`set -euo pipefail` · variables · quoting · the traps newcomers fall into every day
</div>

<div class="stop" data-step="2" markdown>
#### Bash Control Flow
Conditionals, loops, arrays, functions with proper `local` scope and return codes
</div>

<div class="stop" data-step="3" markdown>
#### Bash I/O & Process Model
Here-docs, process substitution, pipes, `xargs -P`, named FIFOs
</div>

<div class="stop" data-step="4" markdown>
#### Bash Automation Patterns
Log rotation, health-check pollers, parallel job runners, bats-core unit tests
</div>

<div class="stop" data-step="5" markdown>
#### Python Foundations for DevOps
Script structure, `subprocess`, `pathlib`, `logging`, YAML/JSON/TOML config handling
</div>

<div class="stop" data-step="6" markdown>
#### Python CLI & Network Layer
`click` CLIs, `requests` with retry, `concurrent.futures`, `pydantic` config models
</div>

<div class="stop" data-step="7" markdown>
#### Python Infrastructure Libraries
`boto3`, kubernetes client, docker SDK, `paramiko`, `fabric`, `prometheus_client`
</div>

<div class="stop" data-step="8" markdown>
#### PhD-Level Meta-Automation
`asyncio` polling, custom Kubernetes controllers (kopf), composable DAG pipelines
</div>

</div>

---

## Hub

<div class="hub" markdown>

<div class="tile" markdown>
**01 · Bash Foundations**  
Examples 1–15 · `set -euo pipefail` through signal handling  
[Read →](01-bash-foundations.md)
</div>

<div class="tile" markdown>
**02 · Bash Advanced**  
Examples 16–25 · Heredoc templates to deployment wrappers  
[Read →](02-bash-advanced.md)
</div>

<div class="tile" markdown>
**03 · Python Foundations**  
Examples 26–35 · subprocess, pathlib, click, pydantic  
[Read →](03-python-foundations.md)
</div>

<div class="tile" markdown>
**04 · Python DevOps Libs**  
Examples 36–50 · boto3, k8s, docker SDK, kopf, DAGs  
[Read →](04-python-devops-libs.md)
</div>

<div class="tile" markdown>
**05 · Challenges & Q&A**  
50 real-world interview questions with full solutions  
[Read →](05-challenges-qna.md)
</div>

<div class="tile" markdown>
**Commands Reference**  
Bash + Python one-liners, test commands, library installs  
[Read →](commands.md)
</div>

</div>

---

## 50-Example Quick-Reference

| # | Example | Difficulty | Category | Page |
|---|---------|-----------|----------|------|
| 1 | `set -euo pipefail` — prod script header | <span class="level beginner">Beginner</span> | Bash Foundations | [01](01-bash-foundations.md#example-1) |
| 2 | Variables, quoting, word splitting | <span class="level beginner">Beginner</span> | Bash Foundations | [01](01-bash-foundations.md#example-2) |
| 3 | `[[ ]]` vs `[ ]` vs `(( ))` | <span class="level beginner">Beginner</span> | Bash Foundations | [01](01-bash-foundations.md#example-3) |
| 4 | Loops: for/while/until + arrays | <span class="level beginner">Beginner</span> | Bash Foundations | [01](01-bash-foundations.md#example-4) |
| 5 | Functions: local vars + return codes | <span class="level beginner">Beginner</span> | Bash Foundations | [01](01-bash-foundations.md#example-5) |
| 6 | `trap` — EXIT/ERR/INT cleanup | <span class="level intermediate">Intermediate</span> | Bash Foundations | [01](01-bash-foundations.md#example-6) |
| 7 | `getopts` — CLI argument parsing | <span class="level intermediate">Intermediate</span> | Bash Foundations | [01](01-bash-foundations.md#example-7) |
| 8 | Here-docs and here-strings | <span class="level intermediate">Intermediate</span> | Bash Foundations | [01](01-bash-foundations.md#example-8) |
| 9 | Process substitution `<()` vs pipes | <span class="level intermediate">Intermediate</span> | Bash Foundations | [01](01-bash-foundations.md#example-9) |
| 10 | `xargs` + parallel processing `-P` | <span class="level intermediate">Intermediate</span> | Bash Foundations | [01](01-bash-foundations.md#example-10) |
| 11 | `awk` for log parsing | <span class="level intermediate">Intermediate</span> | Bash Foundations | [01](01-bash-foundations.md#example-11) |
| 12 | `sed -i` in-place config editing | <span class="level intermediate">Intermediate</span> | Bash Foundations | [01](01-bash-foundations.md#example-12) |
| 13 | Named pipes (FIFOs) for IPC | <span class="level advanced">Advanced</span> | Bash Foundations | [01](01-bash-foundations.md#example-13) |
| 14 | Signal handling + daemonizing | <span class="level advanced">Advanced</span> | Bash Foundations | [01](01-bash-foundations.md#example-14) |
| 15 | Bash strict mode framework | <span class="level advanced">Advanced</span> | Bash Foundations | [01](01-bash-foundations.md#example-15) |
| 16 | Heredoc K8s/Dockerfile generators | <span class="level advanced">Advanced</span> | Bash Advanced | [02](02-bash-advanced.md#example-16) |
| 17 | Log rotation with retention policy | <span class="level advanced">Advanced</span> | Bash Advanced | [02](02-bash-advanced.md#example-17) |
| 18 | Health check with exponential backoff | <span class="level advanced">Advanced</span> | Bash Advanced | [02](02-bash-advanced.md#example-18) |
| 19 | Parallel job runner with semaphore | <span class="level advanced">Advanced</span> | Bash Advanced | [02](02-bash-advanced.md#example-19) |
| 20 | Unit testing with bats-core | <span class="level advanced">Advanced</span> | Bash Advanced | [02](02-bash-advanced.md#example-20) |
| 21 | File watcher with `inotifywait` | <span class="level expert">Expert</span> | Bash Advanced | [02](02-bash-advanced.md#example-21) |
| 22 | Self-updating script (git pull) | <span class="level expert">Expert</span> | Bash Advanced | [02](02-bash-advanced.md#example-22) |
| 23 | Dynamic Ansible inventory generator | <span class="level expert">Expert</span> | Bash Advanced | [02](02-bash-advanced.md#example-23) |
| 24 | Bash DSL — mini config language | <span class="level expert">Expert</span> | Bash Advanced | [02](02-bash-advanced.md#example-24) |
| 25 | Deployment wrapper with rollback | <span class="level expert">Expert</span> | Bash Advanced | [02](02-bash-advanced.md#example-25) |
| 26 | Python script structure + argparse | <span class="level beginner">Beginner</span> | Python Foundations | [03](03-python-foundations.md#example-26) |
| 27 | `subprocess` — safe shell commands | <span class="level beginner">Beginner</span> | Python Foundations | [03](03-python-foundations.md#example-27) |
| 28 | `pathlib` — filesystem operations | <span class="level beginner">Beginner</span> | Python Foundations | [03](03-python-foundations.md#example-28) |
| 29 | `logging` — structured levelled logs | <span class="level beginner">Beginner</span> | Python Foundations | [03](03-python-foundations.md#example-29) |
| 30 | YAML/JSON/TOML config files | <span class="level beginner">Beginner</span> | Python Foundations | [03](03-python-foundations.md#example-30) |
| 31 | `click` — production CLI tools | <span class="level intermediate">Intermediate</span> | Python Foundations | [03](03-python-foundations.md#example-31) |
| 32 | `requests` + retry + backoff | <span class="level intermediate">Intermediate</span> | Python Foundations | [03](03-python-foundations.md#example-32) |
| 33 | `concurrent.futures` parallel calls | <span class="level intermediate">Intermediate</span> | Python Foundations | [03](03-python-foundations.md#example-33) |
| 34 | `dataclasses` + `pydantic` models | <span class="level intermediate">Intermediate</span> | Python Foundations | [03](03-python-foundations.md#example-34) |
| 35 | Context managers for cleanup | <span class="level intermediate">Intermediate</span> | Python Foundations | [03](03-python-foundations.md#example-35) |
| 36 | `boto3` — AWS automation | <span class="level intermediate">Intermediate</span> | Python DevOps | [04](04-python-devops-libs.md#example-36) |
| 37 | Kubernetes Python client | <span class="level intermediate">Intermediate</span> | Python DevOps | [04](04-python-devops-libs.md#example-37) |
| 38 | Docker SDK — build + run | <span class="level intermediate">Intermediate</span> | Python DevOps | [04](04-python-devops-libs.md#example-38) |
| 39 | `paramiko` — SSH automation | <span class="level intermediate">Intermediate</span> | Python DevOps | [04](04-python-devops-libs.md#example-39) |
| 40 | `fabric` — SSH cluster tasks | <span class="level advanced">Advanced</span> | Python DevOps | [04](04-python-devops-libs.md#example-40) |
| 41 | Ansible Python API | <span class="level advanced">Advanced</span> | Python DevOps | [04](04-python-devops-libs.md#example-41) |
| 42 | `prometheus_client` custom metrics | <span class="level advanced">Advanced</span> | Python DevOps | [04](04-python-devops-libs.md#example-42) |
| 43 | `hvac` — Vault secret rotation | <span class="level advanced">Advanced</span> | Python DevOps | [04](04-python-devops-libs.md#example-43) |
| 44 | `GitPython` — branch automation | <span class="level advanced">Advanced</span> | Python DevOps | [04](04-python-devops-libs.md#example-44) |
| 45 | `watchdog` — filesystem events | <span class="level expert">Expert</span> | Python DevOps | [04](04-python-devops-libs.md#example-45) |
| 46 | `celery` — distributed task queue | <span class="level expert">Expert</span> | Python DevOps | [04](04-python-devops-libs.md#example-46) |
| 47 | `asyncio` + `aiohttp` async polling | <span class="level expert">Expert</span> | Python DevOps | [04](04-python-devops-libs.md#example-47) |
| 48 | Custom K8s controller with `kopf` | <span class="level expert">Expert</span> | Python DevOps | [04](04-python-devops-libs.md#example-48) |
| 49 | Python meta-automation (script generator) | <span class="level expert">Expert</span> | Python DevOps | [04](04-python-devops-libs.md#example-49) |
| 50 | Composable DAG pipeline | <span class="level expert">Expert</span> | Python DevOps | [04](04-python-devops-libs.md#example-50) |

---

## Interview Q&A Index

| # | Question | One-line Answer |
|---|----------|-----------------|
| 1 | What does `set -euo pipefail` do? | Exit on error (`-e`), unset var error (`-u`), propagate pipe failures (`-o pipefail`) |
| 2 | When should you use `[[ ]]` vs `[ ]`? | Always `[[ ]]` in bash — no word splitting, regex support, no quoting bugs |
| 3 | How do you safely run shell commands from Python? | `subprocess.run(["cmd", "arg"], check=True)` — never `shell=True` with user input |
| 4 | What's the difference between `$()` and backticks? | `$()` is nestable and readable; backticks are legacy — always use `$()` |
| 5 | How do you pass secrets to scripts without env vars? | Named pipes, `/dev/stdin`, or a secrets manager SDK — never command-line args |
| 6 | What's the purpose of `local` in bash functions? | Prevents variable leakage into the global scope; without it all vars are global |
| 7 | How does `xargs -P` work? | Runs N processes in parallel; combine with `-n1` to process one arg per process |
| 8 | What is `trap` used for? | Registering cleanup handlers for signals: `trap 'cleanup' EXIT ERR INT TERM` |
| 9 | How do you do retries in Python? | `tenacity` library or manual exponential backoff with `time.sleep(2**attempt)` |
| 10 | What's a Kubernetes operator/controller? | A control loop watching CRDs and reconciling actual vs desired state — `kopf` in Python |

---

## Automation Architecture Overview

```mermaid
flowchart LR
    subgraph bash["Bash Layer"]
        B1[set -euo pipefail] --> B2[trap + cleanup]
        B2 --> B3[getopts + validation]
        B3 --> B4[xargs -P parallel]
    end
    subgraph python["Python Layer"]
        P1[argparse / click] --> P2[subprocess / pathlib]
        P2 --> P3[requests + retry]
        P3 --> P4[concurrent.futures]
    end
    subgraph infra["Infrastructure APIs"]
        I1[boto3 AWS]
        I2[kubernetes client]
        I3[docker SDK]
        I4[paramiko SSH]
    end
    subgraph meta["Meta-Automation"]
        M1[kopf K8s controller]
        M2[celery task queue]
        M3[DAG pipeline]
    end
    bash --> python
    python --> infra
    infra --> meta
```
