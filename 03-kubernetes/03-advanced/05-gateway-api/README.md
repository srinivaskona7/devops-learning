# 05 — Gateway API

Gateway API is the successor to Ingress: role-oriented (infra / cluster ops / app dev), portable across implementations, and richer (header-based routing, traffic split, gRPC, TCP/UDP/TLS routes).

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-03-advanced-05-gateway-api-README-1-0bb3ff51.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

<!-- mermaid:rendered -->
<p align="center"><img src="../../../assets/diagrams/03-kubernetes-03-advanced-05-gateway-api-README-1-0bb3ff51.svg" alt="diagram" /></p>

<details><summary>Mermaid source</summary>

```mermaid
flowchart LR
    Infra["GatewayClass<br/>(infra owns)"] --> Gw["Gateway<br/>(cluster ops own)"]
    Gw --> R1["HTTPRoute<br/>(app team A)"]
    Gw --> R2["HTTPRoute<br/>(app team B)"]
    Gw --> R3["GRPCRoute / TCPRoute"]
```

</details>

</details>

## Ingress vs Gateway API

| | Ingress | Gateway API |
|---|--------|-------------|
| Roles | one resource | GatewayClass / Gateway / *Route |
| Extensibility | annotations (vendor-specific) | typed fields, ReferenceGrant |
| Protocols | HTTP(S) only | HTTP, HTTPS, gRPC, TCP, UDP, TLS |
| Traffic split / mirroring | annotations | first-class |
| Mesh integration | none | GAMMA (East-West for service mesh) |

## GAMMA (mesh)
GAMMA = "Gateway API for Mesh Management and Administration". Lets you use the **same `HTTPRoute`** to control east-west traffic inside a mesh (Istio, Linkerd, Cilium, kgateway, etc).

## Implementations (data planes)
- Envoy Gateway, Istio, Cilium, kgateway, NGINX Gateway Fabric, Traefik, Kong, HAProxy, Contour.

## Files
- [gateway.yaml](gateway.yaml)
- [httproute.yaml](httproute.yaml)
