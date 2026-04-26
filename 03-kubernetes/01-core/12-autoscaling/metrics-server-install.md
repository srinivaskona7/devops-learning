# Installing metrics-server

metrics-server provides CPU + memory metrics to HPA and `kubectl top`.

## Install

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## Patch for kind / minikube (self-signed kubelet certs)

```bash
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

## Verify

```bash
kubectl -n kube-system get deploy metrics-server
kubectl top nodes
kubectl top pods -A
```

## Reference

- [metrics-server repo](https://github.com/kubernetes-sigs/metrics-server)
- [Resource Metrics Pipeline](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/)
