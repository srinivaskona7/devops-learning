# Project 04 — CI/CD Pipeline (GitHub Actions → GHCR → GitOps)

Build a complete pipeline: lint → test → build image → Trivy scan → push to GHCR → bump manifest → ArgoCD syncs.

## What you'll build

```mermaid
flowchart LR
  Dev[Push to main] --> CI[GitHub Actions]
  CI --> L[Lint]
  L --> T[Test]
  T --> B[Build Image]
  B --> S[Trivy Scan]
  S --> P[Push to GHCR]
  P --> M[Bump tag in manifests repo]
  M --> A[ArgoCD detects change]
  A --> K[Cluster pulls + deploys]
```

## Prerequisites
- Project 01 (hello-world app + Dockerfile)
- Project 03 (ArgoCD watching your manifests)
- GitHub repo with Actions enabled
- Repo secrets: `GHCR_PAT` (PAT with `write:packages` + `repo`)

## Step 1 — Drop in the workflow

Copy `.github-workflow-example.yaml` to `.github/workflows/build-deploy.yaml` at the repo root.

```bash
mkdir -p .github/workflows
cp 10-projects/04-ci-cd-pipeline/.github-workflow-example.yaml \
   .github/workflows/build-deploy.yaml
git add .github/workflows/build-deploy.yaml
git commit -m "ci: add build-deploy pipeline"
git push
```

## Step 2 — What the workflow does

1. **Trigger** — push to `main` that touches `10-projects/01-hello-world-end-to-end/**`.
2. **lint** — run `flake8` over `app/`.
3. **test** — placeholder `pytest` step (add real tests).
4. **build** — `docker buildx` with cache, multi-arch (amd64/arm64).
5. **scan** — Trivy fails on `HIGH,CRITICAL` CVEs.
6. **push** — push to `ghcr.io/<owner>/hello-world:<sha>` and `:latest`.
7. **update-manifest** — `sed` updates `image:` in `k8s/deployment.yaml` and commits back.
8. **ArgoCD** picks up the commit and rolls out.

## Step 3 — Verify

```bash
# Watch the run in the Actions tab. After it finishes:
git pull
grep image k8s/deployment.yaml   # should show new sha tag

# In the cluster:
kubectl -n proj01 rollout status deploy/hello-world
kubectl -n proj01 get pod -l app=hello-world -o jsonpath='{.items[0].spec.containers[0].image}'
```

## Step 4 — Test the security gate

Introduce a vulnerable base image (e.g. `python:3.8`) and push. Trivy step should **fail** — no image is pushed, no manifest update happens.

## Cleanup

```bash
gh workflow disable build-deploy.yaml
# Optionally delete old GHCR image versions in the Packages UI
```

## What you learned
- Multi-stage CI: lint, test, build, scan, push, deploy
- GitOps trigger via manifest commit (no `kubectl` from CI)
- Trivy as a hard gate
- Image caching with BuildKit / GHA cache
- Least-privilege `GITHUB_TOKEN` permissions

## Stretch goals
- Sign images with `cosign` and verify in cluster with policy-controller
- Replace `sed` with Kustomize image transformer or Argo Image Updater
- Add a PR preview environment (per-PR namespace + ingress)
- Add SBOM generation (`trivy sbom` or `syft`) and upload to dependency-track

## Related
- See [`../../08-security/02-image-scanning/`](../../08-security/) for Trivy deep-dive
- See [`../03-gitops-with-argocd/`](../03-gitops-with-argocd/) for the ArgoCD side
