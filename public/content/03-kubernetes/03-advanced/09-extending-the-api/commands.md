# Extending the API — Commands

> Quick pickup reference. Pair with `README.md` for theory. Covers CRDs, aggregation layer, APF, finalizers.

## Setup

```bash
kubectl cluster-info
kubectl api-resources | head
```

## Apply manifests

```bash
kubectl apply -f apf-example.yaml
```

## CRD inspection

```bash
kubectl get crd
kubectl describe crd <plural>.<group>
kubectl explain <kind> --recursive | head -40
kubectl api-resources --verbs=list -o name | grep <group>
```

## Aggregation layer

```bash
kubectl get apiservice
kubectl get apiservice | grep -v Local              # external (aggregated) APIs
kubectl describe apiservice v1beta1.metrics.k8s.io
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes | jq
kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1 | jq
```

## API Priority and Fairness (APF)

```bash
kubectl get flowschema
kubectl get prioritylevelconfiguration
kubectl describe flowschema <name>
kubectl describe prioritylevelconfiguration <name>

# Inspect APF metrics
kubectl get --raw /metrics | grep apiserver_flowcontrol | head -20
```

## Finalizers

```bash
# See finalizers on an object
kubectl get <kind> <name> -o jsonpath='{.metadata.finalizers}'; echo

# Force-remove a stuck finalizer (BREAK GLASS)
kubectl patch <kind> <name> --type=merge -p '{"metadata":{"finalizers":null}}'

# Namespace stuck in Terminating
kubectl get namespace <ns> -o json \
  | jq '.spec.finalizers=[]' \
  | kubectl replace --raw "/api/v1/namespaces/<ns>/finalize" -f -
```

## Validation with CEL (`x-kubernetes-validations`)

```bash
# Apply a violating CR — server returns the CEL error message
kubectl apply -f bad-cr.yaml --dry-run=server
```

## Inspect built-in admission flow

```bash
kubectl get validatingadmissionpolicy
kubectl get validatingadmissionpolicybinding
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
```

## Cleanup

```bash
kubectl delete -f apf-example.yaml --ignore-not-found
```

## One-liners worth memorising

```bash
kubectl get crd
kubectl get apiservice
kubectl get flowschema
kubectl get prioritylevelconfiguration
kubectl explain <kind>.spec --recursive
kubectl patch <kind> <name> --type=merge -p '{"metadata":{"finalizers":null}}'
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes | jq
```
