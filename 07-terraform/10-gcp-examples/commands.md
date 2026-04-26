# GCP Examples — Commands

> Quick pickup reference. Pair with `README.md` for theory.
> GKE costs real money — always destroy after testing.

## Setup

```bash
cd 10-gcp-examples

# Auth — Application Default Credentials
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

export GOOGLE_PROJECT=YOUR_PROJECT_ID
export GOOGLE_REGION=europe-west1

# Verify
gcloud auth list
gcloud config list
gcloud projects describe "$GOOGLE_PROJECT"
```

## Init / plan / apply

```bash
terraform init
terraform plan -var="project_id=$GOOGLE_PROJECT"
terraform plan -out=tfplan -var="project_id=$GOOGLE_PROJECT"
terraform apply tfplan

# Apply one resource at a time
terraform apply -target=google_storage_bucket.demo \
                -var="project_id=$GOOGLE_PROJECT"
terraform apply -target=module.gke \
                -var="project_id=$GOOGLE_PROJECT"
```

## State operations

```bash
terraform state list
terraform state show google_storage_bucket.demo
terraform state show google_container_cluster.demo

# Import an existing GCP resource
terraform import google_storage_bucket.adopted my-existing-bucket
terraform import \
  google_container_cluster.imported \
  projects/$GOOGLE_PROJECT/locations/europe-west1/clusters/my-cluster
```

## Inspect / verify

```bash
terraform output
terraform output -raw bucket_name
terraform output -raw cluster_endpoint

# Verify with gcloud
gcloud storage buckets list
gcloud storage buckets describe "gs://$(terraform output -raw bucket_name)"
gcloud container clusters list --region="$GOOGLE_REGION"

# Wire up kubectl for the GKE cluster
gcloud container clusters get-credentials \
  "$(terraform output -raw cluster_name)" \
  --region "$GOOGLE_REGION"
kubectl get nodes
kubectl get pods -A
```

## Cleanup (destroy)

```bash
# GKE first
terraform destroy -target=module.gke \
                  -var="project_id=$GOOGLE_PROJECT" -auto-approve
terraform destroy -var="project_id=$GOOGLE_PROJECT" -auto-approve

# Sanity-check nothing leftover
gcloud container clusters list --region="$GOOGLE_REGION"
gcloud storage buckets list | grep demo
```

## One-liners worth memorising

```bash
# Drift check
terraform plan -refresh-only -var="project_id=$GOOGLE_PROJECT"

# Switch region without editing HCL
TF_VAR_region=us-central1 terraform plan -var="project_id=$GOOGLE_PROJECT"

# Force-replace a resource
terraform apply -replace=google_storage_bucket.demo \
                -var="project_id=$GOOGLE_PROJECT"

# Bake project_id into env so commands shorten
export TF_VAR_project_id="$GOOGLE_PROJECT"
terraform plan
terraform apply -auto-approve

# Verify the right service account is in use
gcloud auth application-default print-access-token | head -c 40 ; echo
```
