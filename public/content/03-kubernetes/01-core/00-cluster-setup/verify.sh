#!/usr/bin/env bash
# Verify the cluster is healthy. Run after `kind create cluster`.
set -euo pipefail

echo "==> Cluster info"
kubectl cluster-info

echo "==> Nodes"
kubectl get nodes -o wide

echo "==> System pods"
kubectl get pods -n kube-system

echo "==> API resources sample"
kubectl api-resources | head -20

echo "==> Current context"
kubectl config current-context

echo
echo "OK: cluster ready. Proceed to ../02-pods/"
