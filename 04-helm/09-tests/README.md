# 09 — Helm Tests

`helm test` runs Pods/Jobs annotated as `helm.sh/hook: test` against a deployed release.

## Flow

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/04-helm-09-tests-README-1-9a7f8534.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/04-helm-09-tests-README-1-9a7f8534.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../assets/diagrams/04-helm-09-tests-README-1-9a7f8534.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
sequenceDiagram
    participant U as User
    participant H as Helm
    participant K as K8s
    U->>H: helm install demo ./chart
    H->>K: deploy resources
    U->>H: helm test demo
    H->>K: create test pods (hook=test)
    K-->>H: Pod exits 0 → PASS / non-zero → FAIL
    U->>H: helm test demo --logs (show pod logs)
```

</details>

</details>

</details>

## Layout

```
mychart/
└── templates/
    └── tests/
        └── test-connection.yaml
```

## Run

```bash
helm install demo ./mychart
helm test demo
helm test demo --logs       # stream test pod logs
helm test demo --filter name=demo-test-connection
```

## Pattern: Connection Test

See [test-connection.yaml](./test-connection.yaml) — a busybox/wget pod that hits the service and exits 0/1.

## CI Integration

```bash
helm install demo ./mychart --wait --atomic
helm test demo --logs || (helm uninstall demo && exit 1)
helm uninstall demo
```

## Tips

- Always set `hook-delete-policy` so test pods don't accumulate.
- Keep tests fast (< 60s). Long suites belong in proper E2E.
- A failing test rolls back when combined with `--atomic`.
