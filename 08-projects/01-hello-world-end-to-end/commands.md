# Project 01 (Hello World End-to-End) — Commands

> Quick pickup reference. Full walkthrough in `README.md`.

## Prerequisites
```bash
docker info                       # daemon running
kubectl get nodes                 # cluster reachable
kubectl -n ingress-nginx get pods # ingress-nginx installed
export GH_USER=<your-github-user>
export CR_PAT=<gh-pat-with-write:packages>
```

## Build
```bash
cd 08-projects/01-hello-world-end-to-end

docker build -t hello-world:0.1.0 .

# Smoke test locally
docker run --rm -d -p 8080:8080 --name hw hello-world:0.1.0
curl -s http://localhost:8080/         # -> Hello, world!
curl -s http://localhost:8080/healthz  # -> ok
docker rm -f hw
```

## Deploy
```bash
# Push to GHCR
echo "$CR_PAT" | docker login ghcr.io -u "$GH_USER" --password-stdin
docker tag  hello-world:0.1.0 ghcr.io/$GH_USER/hello-world:0.1.0
docker push ghcr.io/$GH_USER/hello-world:0.1.0

# Replace GHCR_USER placeholder before applying
sed -i.bak "s/GHCR_USER/$GH_USER/g" k8s/deployment.yaml

kubectl create namespace proj01
kubectl -n proj01 apply -f k8s/deployment.yaml
kubectl -n proj01 apply -f k8s/service.yaml
kubectl -n proj01 apply -f k8s/ingress.yaml
kubectl -n proj01 rollout status deploy/hello-world
```

## Verify
```bash
kubectl -n proj01 get pods,svc,ingress

INGRESS_IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "$INGRESS_IP hello.local" | sudo tee -a /etc/hosts

curl -s http://hello.local/         # -> Hello, world!
curl -s http://hello.local/healthz  # -> ok

# Pod-level health
kubectl -n proj01 logs -l app=hello-world --tail=20
kubectl -n proj01 describe deploy/hello-world | grep -A2 Liveness
```

## Cleanup
```bash
kubectl delete namespace proj01
sudo sed -i '' '/hello.local/d' /etc/hosts
docker rmi hello-world:0.1.0 ghcr.io/$GH_USER/hello-world:0.1.0 || true
mv k8s/deployment.yaml.bak k8s/deployment.yaml 2>/dev/null || true
```

## One-liners worth memorising
```bash
# Watch rollout in real time
kubectl -n proj01 rollout status deploy/hello-world

# Restart pods (no manifest change)
kubectl -n proj01 rollout restart deploy/hello-world

# Quick port-forward when ingress is broken
kubectl -n proj01 port-forward svc/hello-world 8080:80

# Confirm image actually pulled
kubectl -n proj01 get pod -l app=hello-world \
  -o jsonpath='{.items[0].spec.containers[0].image}'; echo
```
