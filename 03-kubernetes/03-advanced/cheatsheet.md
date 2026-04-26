# Kubernetes Advanced Cheatsheet

## CRDs / Operators
```bash
kubectl get crd
kubectl explain foo.example.com --recursive
kubectl api-resources --api-group=example.com
```

## Admission
```bash
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
kubectl get validatingadmissionpolicies          # 1.30 GA
```

## Scheduling
```bash
kubectl describe node <n> | grep -A5 Taints
kubectl get pods -o wide --field-selector spec.nodeName=<n>
kubectl get priorityclasses
```

## Service Mesh / Gateway API
```bash
istioctl proxy-status
istioctl proxy-config routes <pod>
kubectl get gateway,httproute -A
```

## Debugging
```bash
kubectl debug -it <pod> --image=busybox --target=<container>
kubectl debug node/<node> -it --image=busybox
kubectl logs <pod> --previous
kubectl get events --sort-by=.lastTimestamp
kubectl top pod / kubectl top node
```

## Audit / Feature gates
```bash
kubectl get --raw /metrics | grep apiserver_request_total
kube-apiserver --feature-gates=InPlacePodVerticalScaling=true
```

## Version skew
```bash
kubectl version --short
# control-plane and kubelet within +/- 1 minor; kubectl within +/- 1
```
