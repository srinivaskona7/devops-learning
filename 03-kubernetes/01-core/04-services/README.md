# 04 — Services

> Pods are mortal — their IPs change. **A Service is a stable virtual IP + DNS name** that load-balances to a set of pods selected by labels.

## Why Services

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-01-core-04-services-README-1-8740b46e.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-01-core-04-services-README-1-8740b46e.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-01-core-04-services-README-1-8740b46e.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  C[Client / other pod] -->|service-name:80| SVC[Service<br/>ClusterIP 10.96.x.y]
  SVC -.kube-proxy.- P1[Pod 10.244.1.5]
  SVC -.kube-proxy.- P2[Pod 10.244.2.7]
  SVC -.kube-proxy.- P3[Pod 10.244.1.9]
```

</details>

</details>

</details>

Without a Service, you'd hardcode pod IPs. With one, you call `http://hello-app.default.svc.cluster.local` and traffic round-robins to healthy backends.

## Service types

| Type | What it does | When to use |
|------|--------------|-------------|
| **ClusterIP** (default) | Stable VIP only inside the cluster | East-west pod-to-pod |
| **NodePort** | Exposes service on every node's IP at a static port (30000–32767) | Quick external access in dev |
| **LoadBalancer** | Provisions a cloud LB (AWS ELB, GCP, Azure) | Public-facing services in cloud |
| **ExternalName** | DNS CNAME to an external host | Abstract external services |
| **Headless** (`clusterIP: None`) | No VIP — DNS returns pod IPs directly | StatefulSets, custom LB |

## kube-proxy modes

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-01-core-04-services-README-2-dfe774c2.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-01-core-04-services-README-2-dfe774c2.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-01-core-04-services-README-2-dfe774c2.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
  KP[kube-proxy] --> IPT[iptables<br/>random backend per conn]
  KP --> IPVS[IPVS<br/>real LB algorithms]
  KP --> NFT[nftables<br/>newer, faster]
```

</details>

</details>

</details>

## Apply & observe

```bash
# First create a backend deployment
kubectl apply -f ../03-deployments/deployment.yaml

# ClusterIP
kubectl apply -f clusterip.yaml
kubectl get svc hello-app
kubectl run tmp --rm -it --image=curlimages/curl --restart=Never -- \
  curl -s http://hello-app/

# NodePort
kubectl apply -f nodeport.yaml
kubectl get svc hello-app-np
# kind: port-forward; minikube: minikube service hello-app-np --url

# Headless
kubectl apply -f headless.yaml
kubectl run tmp --rm -it --image=busybox --restart=Never -- \
  nslookup hello-app-headless    # ← returns multiple A records, one per pod

# Endpoints (the actual pod IPs behind a Service)
kubectl get endpoints hello-app
kubectl get endpointslices -l kubernetes.io/service-name=hello-app
```

## DNS

```
<service>.<namespace>.svc.cluster.local
hello-app.default.svc.cluster.local → ClusterIP 10.96.x.y
```

Same-namespace? Just `hello-app`.

## Cleanup

```bash
kubectl delete -f clusterip.yaml -f nodeport.yaml -f headless.yaml
```

## Gotchas

> ⚠️ **Service `selector` must match Pod labels.** A typo = empty Endpoints = "connection refused".

> ⚠️ **NodePort opens a port on EVERY node.** Firewall accordingly.

> ⚠️ **LoadBalancer in kind/minikube stays `Pending`** unless you install [MetalLB](https://metallb.universe.tf/) or use `minikube tunnel`.

> ⚠️ **Headless services have no load balancing.** Your client (or DNS resolver) picks a pod.

## Reference

- [Service](https://kubernetes.io/docs/concepts/services-networking/service/)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/)
