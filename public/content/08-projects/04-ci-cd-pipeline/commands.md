# Project 04 (CI/CD Pipeline) — Commands

> Quick pickup reference. Full walkthrough in `README.md`.

## Prerequisites
```bash
gh auth status                    # GitHub CLI logged in
# Repo secret: GHCR_PAT (write:packages + repo)
gh secret list

# Confirm Project 01 + Project 03 are already in place
kubectl -n proj01   get deploy hello-world
kubectl -n argocd   get application hello-world
```

## Build
The pipeline IS the build. Drop the workflow in place:
```bash
# From repo root
mkdir -p .github/workflows
cp 08-projects/04-ci-cd-pipeline/.github-workflow-example.yaml \
   .github/workflows/build-deploy.yaml

git add .github/workflows/build-deploy.yaml
git commit -m "ci: add build-deploy pipeline"
git push
```

## Deploy
The push above triggers everything. Stages:
1. lint (`flake8`)
2. test (`pytest`)
3. buildx (multi-arch, cached)
4. trivy scan (fails on HIGH/CRITICAL)
5. push to `ghcr.io/<owner>/hello-world:<sha>` + `:latest`
6. `sed` updates `k8s/deployment.yaml`, commits back
7. ArgoCD reconciles within ~3 minutes

Trigger manually too:
```bash
gh workflow run build-deploy.yaml
gh run list --workflow=build-deploy.yaml --limit 5
gh run watch
```

## Verify
```bash
# Pipeline status
gh run list --workflow=build-deploy.yaml --limit 3
gh run view --log-failed

# Manifest got bumped
git pull
grep image 08-projects/01-hello-world-end-to-end/k8s/deployment.yaml

# Cluster picked it up
kubectl -n proj01 rollout status deploy/hello-world
kubectl -n proj01 get pod -l app=hello-world \
  -o jsonpath='{.items[0].spec.containers[0].image}'; echo

# Security gate test: introduce a bad base image, push, expect Trivy fail
# (no image push, no manifest update)
```

## Cleanup
```bash
gh workflow disable build-deploy.yaml
# Optional: delete old image versions in the GHCR Packages UI
gh api -X DELETE /user/packages/container/hello-world/versions/<id>
```

## One-liners worth memorising
```bash
# Re-run last failed run
gh run rerun --failed $(gh run list --workflow=build-deploy.yaml --limit 1 --json databaseId -q '.[0].databaseId')

# Trivy locally before pushing
trivy image --severity HIGH,CRITICAL --exit-code 1 hello-world:0.1.0

# Buildx multi-arch local build
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/$GH_USER/hello-world:dev --push .

# Compare cluster image vs git
diff <(kubectl -n proj01 get deploy hello-world -o jsonpath='{.spec.template.spec.containers[0].image}') \
     <(grep image: 08-projects/01-hello-world-end-to-end/k8s/deployment.yaml | awk '{print $2}')
```
