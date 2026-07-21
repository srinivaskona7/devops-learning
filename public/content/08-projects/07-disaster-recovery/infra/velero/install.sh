#!/usr/bin/env bash
# =============================================================================
# infra/velero/install.sh
# Installs Velero with the AWS plugin, S3 backend, and restic node-agent.
#
# Prerequisites:
#   - kubectl context set to the target cluster
#   - AWS CLI configured with permissions to create S3 buckets + IAM roles
#   - velero CLI installed: brew install velero
#   - Helm 3: brew install helm
#
# Usage:
#   CLUSTER=primary REGION=us-east-1 BUCKET=dr-velero-primary ./infra/velero/install.sh
#   CLUSTER=secondary REGION=us-west-2 BUCKET=dr-velero-secondary ./infra/velero/install.sh
#
# Environment variables (all required):
#   CLUSTER   - "primary" or "secondary"
#   REGION    - AWS region for this cluster
#   BUCKET    - S3 bucket name (must already exist or BUCKET_CREATE=true)
#   BUCKET_CREATE - set to "true" to create the bucket if missing (default: false)
# =============================================================================
set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────
CLUSTER="${CLUSTER:?CLUSTER must be set to 'primary' or 'secondary'}"
REGION="${REGION:?REGION must be set, e.g. us-east-1}"
BUCKET="${BUCKET:?BUCKET must be set to the S3 bucket name}"
BUCKET_CREATE="${BUCKET_CREATE:-false}"

VELERO_NAMESPACE="velero"
VELERO_PLUGIN_VERSION="v1.10.0"
VELERO_VERSION="v1.13.2"
IRSA_ROLE_ARN="${IRSA_ROLE_ARN:-}"  # optional; if set, use IRSA instead of static creds

# Service account for IRSA
SA_NAME="velero"
SA_NAMESPACE="${VELERO_NAMESPACE}"

# ─── Helpers ────────────────────────────────────────────────────────────────
log()  { printf '\033[0;32m[velero-install] %s\033[0m\n' "$*"; }
warn() { printf '\033[0;33m[velero-install] WARN: %s\033[0m\n' "$*"; }
die()  { printf '\033[0;31m[velero-install] ERROR: %s\033[0m\n' "$*"; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed"; }

# ─── Preflight checks ───────────────────────────────────────────────────────
log "Preflight: checking required tools"
require_cmd kubectl
require_cmd velero
require_cmd aws
require_cmd helm

CURRENT_CONTEXT=$(kubectl config current-context)
log "kubectl context: ${CURRENT_CONTEXT}"
read -rp "Continue with this context? [y/N] " confirm
[[ "${confirm}" =~ ^[Yy]$ ]] || die "Aborted by user"

# ─── S3 bucket setup ────────────────────────────────────────────────────────
log "Checking S3 bucket: ${BUCKET} in ${REGION}"

if ! aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  if [[ "${BUCKET_CREATE}" == "true" ]]; then
    log "Creating S3 bucket: ${BUCKET}"
    if [[ "${REGION}" == "us-east-1" ]]; then
      # us-east-1 does NOT accept LocationConstraint
      aws s3api create-bucket \
        --bucket "${BUCKET}" \
        --region "${REGION}"
    else
      aws s3api create-bucket \
        --bucket "${BUCKET}" \
        --region "${REGION}" \
        --create-bucket-configuration LocationConstraint="${REGION}"
    fi

    # Enforce encryption at rest (AES-256 or KMS)
    aws s3api put-bucket-encryption \
      --bucket "${BUCKET}" \
      --server-side-encryption-configuration '{
        "Rules": [{
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "aws:kms"
          },
          "BucketKeyEnabled": true
        }]
      }'

    # Block all public access
    aws s3api put-public-access-block \
      --bucket "${BUCKET}" \
      --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    # Enable versioning — lets velero recover from accidental deletes
    aws s3api put-bucket-versioning \
      --bucket "${BUCKET}" \
      --versioning-configuration Status=Enabled

    # Lifecycle: expire non-current versions after 30 days, delete after 365
    aws s3api put-bucket-lifecycle-configuration \
      --bucket "${BUCKET}" \
      --lifecycle-configuration '{
        "Rules": [{
          "ID": "velero-retention",
          "Status": "Enabled",
          "Filter": {},
          "NoncurrentVersionExpiration": { "NoncurrentDays": 30 },
          "Expiration": { "Days": 365 }
        }]
      }'
  else
    die "Bucket ${BUCKET} does not exist. Set BUCKET_CREATE=true to create it."
  fi
fi

log "S3 bucket ${BUCKET} is ready"

# ─── IAM policy for Velero ──────────────────────────────────────────────────
POLICY_NAME="velero-${CLUSTER}-policy"
POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVolumes",
        "ec2:DescribeSnapshots",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:CreateSnapshot",
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:PutObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts"
      ],
      "Resource": "arn:aws:s3:::${BUCKET}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::${BUCKET}"
    }
  ]
}
EOF
)

log "Creating/updating IAM policy: ${POLICY_NAME}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

if aws iam get-policy --policy-arn "${POLICY_ARN}" 2>/dev/null; then
  warn "Policy ${POLICY_NAME} already exists — skipping creation"
else
  aws iam create-policy \
    --policy-name "${POLICY_NAME}" \
    --policy-document "${POLICY_DOC}"
  log "Created IAM policy: ${POLICY_ARN}"
fi

# ─── Install Velero via Helm ─────────────────────────────────────────────────
log "Adding Velero Helm repo"
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

log "Creating namespace: ${VELERO_NAMESPACE}"
kubectl create namespace "${VELERO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Build Helm values
HELM_VALUES=$(cat <<EOF
# Velero Helm values — generated by install.sh
# Cluster: ${CLUSTER}  Region: ${REGION}  Bucket: ${BUCKET}

initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:${VELERO_PLUGIN_VERSION}
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins

configuration:
  backupStorageLocation:
    - name: default
      provider: aws
      bucket: ${BUCKET}
      prefix: velero
      default: true
      config:
        region: ${REGION}
        s3ForcePathStyle: "false"
        s3Url: ""

  volumeSnapshotLocation:
    - name: default
      provider: aws
      config:
        region: ${REGION}

  # Upload partial backups even if some objects fail
  # Reduces RTO for partial failures
  uploaderType: restic

credentials:
  useSecret: false   # Using IRSA — set to true for static credentials

serviceAccount:
  server:
    create: true
    name: ${SA_NAME}
    annotations:
      eks.amazonaws.com/role-arn: "${IRSA_ROLE_ARN}"

nodeAgent:
  # nodeAgent runs restic on each node for PVC backup
  podVolumePath: /var/lib/kubelet/pods
  privileged: false
  tolerations:
    - operator: Exists
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

resources:
  requests:
    cpu: 500m
    memory: 128Mi
  limits:
    cpu: 1000m
    memory: 512Mi

metrics:
  enabled: true
  serviceMonitor:
    enabled: true   # requires prometheus-operator

# Store logs for failed backups (default: 72h)
backupSyncPeriod: 1m
resyncPeriod: 5m
defaultBackupTTL: 720h    # 30 days
EOF
)

log "Installing Velero ${VELERO_VERSION} via Helm"
echo "${HELM_VALUES}" | helm upgrade --install velero vmware-tanzu/velero \
  --namespace "${VELERO_NAMESPACE}" \
  --version "${VELERO_VERSION}" \
  --values - \
  --wait \
  --timeout 5m

log "Waiting for Velero deployment to be ready"
kubectl -n "${VELERO_NAMESPACE}" rollout status deployment/velero --timeout=180s

# ─── Verify installation ─────────────────────────────────────────────────────
log "Verifying Velero installation"
velero version

log "Checking BackupStorageLocation"
kubectl -n "${VELERO_NAMESPACE}" get backupstoragelocation default

# ─── Apply backup schedule ───────────────────────────────────────────────────
log "Applying backup schedule"
kubectl apply -f "$(dirname "$0")/schedule.yaml"

log ""
log "============================================================"
log "  Velero installed successfully!"
log "  Cluster:  ${CLUSTER}"
log "  Region:   ${REGION}"
log "  Bucket:   ${BUCKET}"
log "  IRSA ARN: ${IRSA_ROLE_ARN:-NOT SET — using node IAM role}"
log ""
log "  Verify: velero backup-location get"
log "  Take a test backup: velero backup create smoke-$(date +%s) --include-namespaces default"
log "============================================================"
