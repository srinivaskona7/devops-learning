# Helm Tests — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# tests are pods/jobs annotated `helm.sh/hook: test`
# convention: place them under templates/tests/
ls mychart/templates/tests/
```

## Core commands

```bash
# install the release first
helm install demo ./mychart

# run all tests for the release
helm test demo

# stream test pod logs (see WHY a test failed)
helm test demo --logs

# run only one test pod by name
helm test demo --filter name=demo-test-connection

# scope to a namespace
helm test demo -n web --logs
```

## Inspect / verify

```bash
# test pods stay around unless hook-delete-policy is set
kubectl get pods -l helm.sh/hook=test -A

# describe a failing test
kubectl describe pod <release>-test-connection -n <ns>
kubectl logs <release>-test-connection -n <ns>

# confirm test templates render
helm template demo ./mychart -s templates/tests/test-connection.yaml
```

## Cleanup

```bash
# remove leftover test pods by hand (avoid by setting hook-delete-policy)
kubectl delete pod -l helm.sh/hook=test -n <ns>

# tear down the release entirely
helm uninstall demo
```

## One-liners worth memorising

```bash
# CI gate: install, test, uninstall on failure
helm install demo ./mychart --wait --atomic
helm test demo --logs || (helm uninstall demo && exit 1)
helm uninstall demo

# combine with --atomic so a failed test rolls back the release
helm upgrade --install demo ./mychart --atomic --wait && helm test demo --logs

# always set on test manifests to prevent stale pods piling up:
#   "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
```
