# CRDs & Operators — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
kubectl cluster-info
kubectl api-resources | head
```

## Apply manifests

```bash
kubectl apply -f example-crd.yaml
```

## Inspect / verify

```bash
kubectl get crd
kubectl get crd <name>.<group>
kubectl describe crd <name>.<group>
kubectl explain <kind> --recursive | head -40
kubectl api-resources | grep <group>
```

## Common operations — work with a CR

```bash
# After CRD is installed
kubectl apply -f my-cr.yaml
kubectl get <plural>
kubectl get <plural> -o yaml
kubectl describe <kind> <name>
kubectl edit <kind> <name>
kubectl delete <kind> <name>
```

## Validate a CRD's schema (dry-run)

```bash
kubectl apply -f my-cr.yaml --dry-run=server
kubectl apply -f my-cr.yaml --dry-run=server --validate=true
```

## Build an operator (Kubebuilder)

```bash
go install sigs.k8s.io/kubebuilder/v4@latest
mkdir my-operator && cd my-operator
kubebuilder init --domain example.com --repo github.com/me/my-operator
kubebuilder create api --group apps --version v1alpha1 --kind MyApp
make generate manifests
make install                                    # install CRDs into cluster
make run                                        # run controller locally against cluster
make docker-build docker-push IMG=ghcr.io/me/my-operator:dev
make deploy IMG=ghcr.io/me/my-operator:dev
```

## Operator SDK alternative

```bash
brew install operator-sdk
operator-sdk init --domain=example.com --repo=github.com/me/op
operator-sdk create api --group=apps --version=v1alpha1 --kind=MyApp --resource --controller
make manifests
make install
make run
```

## Inspect controller behavior

```bash
kubectl logs -n <op-ns> deploy/<controller> -f
kubectl get events -A --sort-by=.lastTimestamp | tail -20
kubectl get <kind> <name> -o jsonpath='{.status}'
```

## Cleanup

```bash
kubectl delete -f example-crd.yaml --ignore-not-found
make uninstall                                  # if using kubebuilder
```

## One-liners worth memorising

```bash
kubectl get crd
kubectl explain <kind>.spec --recursive
kubectl api-resources | grep <group>
kubectl apply -f my-cr.yaml --dry-run=server
kubectl get <kind> -A
```
