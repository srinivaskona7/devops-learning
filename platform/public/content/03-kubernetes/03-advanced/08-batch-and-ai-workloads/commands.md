# Batch & AI Workloads — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup — Kueue

```bash
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/kueue/releases/latest/download/manifests.yaml
kubectl -n kueue-system get pods
kubectl get clusterqueue,resourceflavor,localqueue -A
```

## Setup — JobSet

```bash
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/jobset/releases/latest/download/manifests.yaml
kubectl -n jobset-system get pods
kubectl get jobset -A
```

## Apply manifests

```bash
kubectl apply -f indexed-job.yaml
kubectl apply -f kueue-localqueue.yaml
```

## Inspect / verify — Jobs

```bash
kubectl get jobs
kubectl get pods -l job-name=<name>
kubectl get job <name> -o jsonpath='{.status}' | jq
kubectl logs job/<name>
kubectl logs -l job-name=<name> --tail=200 --max-log-requests=10
```

## Indexed Job (per-pod index)

```bash
kubectl get pods -l job-name=<name> \
  -o custom-columns=POD:.metadata.name,INDEX:.metadata.annotations.batch\.kubernetes\.io/job-completion-index
```

## Kueue queue ops

```bash
kubectl get clusterqueue
kubectl get localqueue -A
kubectl get workload -A                    # admitted / pending workloads
kubectl describe workload <name>
```

## Volcano (gang scheduling)

```bash
kubectl apply -f \
  https://raw.githubusercontent.com/volcano-sh/volcano/master/installer/volcano-development.yaml
kubectl get pods -n volcano-system
kubectl get vcjob -A
kubectl describe vcjob <name>
```

## GPU workloads

```bash
# Verify GPU resource is exposed (NVIDIA device plugin installed)
kubectl get nodes -o json \
  | jq '.items[].status.allocatable | {gpu: ."nvidia.com/gpu"}'

# Pod requesting a GPU
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: gpu-test }
spec:
  restartPolicy: Never
  containers:
    - name: cuda
      image: nvidia/cuda:12.2.0-base-ubuntu22.04
      command: [nvidia-smi]
      resources: { limits: { "nvidia.com/gpu": 1 } }
EOF
kubectl logs gpu-test
```

## Kubeflow / KubeRay

```bash
# Kubeflow (full)
kubectl apply -k "github.com/kubeflow/manifests/example?ref=master"

# KubeRay
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm install kuberay-operator kuberay/kuberay-operator -n kuberay --create-namespace
kubectl get raycluster,rayjob,rayservice -A
```

## Cleanup

```bash
kubectl delete -f indexed-job.yaml -f kueue-localqueue.yaml --ignore-not-found

# TTL auto-cleans completed Jobs
kubectl get jobs --field-selector status.successful=1
```

## One-liners worth memorising

```bash
kubectl get jobs,cronjob,jobset -A
kubectl get clusterqueue,localqueue,workload -A
kubectl logs job/<name>
kubectl logs -l job-name=<name> --tail=200 --max-log-requests=10
kubectl create job --from=cronjob/<name> manual-1
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'
```
