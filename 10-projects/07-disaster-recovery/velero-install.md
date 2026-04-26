# Velero Install — IRSA Edition (production)

Static AWS credentials in a Secret are fine for dev but **don't ship them**. Use IRSA on EKS.

## 1. IAM policy for Velero

`velero-policy.json`:

```json
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
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::${BUCKET}"
    }
  ]
}
```

```bash
envsubst < velero-policy.json > velero-policy.rendered.json
aws iam create-policy --policy-name VeleroBackup \
  --policy-document file://velero-policy.rendered.json
```

## 2. IRSA role

```bash
CLUSTER=devops-learning-eks
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
OIDC=$(aws eks describe-cluster --name $CLUSTER \
  --query 'cluster.identity.oidc.issuer' --output text | sed 's|https://||')

cat > trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::${ACCOUNT}:oidc-provider/${OIDC}" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "${OIDC}:sub": "system:serviceaccount:velero:velero",
        "${OIDC}:aud": "sts.amazonaws.com"
      }
    }
  }]
}
EOF

aws iam create-role --role-name VeleroEKS --assume-role-policy-document file://trust.json
aws iam attach-role-policy --role-name VeleroEKS \
  --policy-arn arn:aws:iam::${ACCOUNT}:policy/VeleroBackup
```

## 3. Install Velero with the IRSA SA

```bash
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.10.0 \
  --bucket $BUCKET \
  --backup-location-config region=$REGION \
  --snapshot-location-config region=$REGION \
  --no-secret \
  --pod-annotations iam.amazonaws.com/role=VeleroEKS \
  --service-account-annotations eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT}:role/VeleroEKS \
  --use-node-agent
```

## 4. Verify

```bash
kubectl -n velero get sa velero -o yaml | grep eks.amazonaws.com/role-arn
kubectl -n velero logs deploy/velero | grep -i 'backup storage location is valid'
```

## 5. Common errors

| Error | Likely cause |
|-------|--------------|
| `AccessDenied: ListBucket` | Role doesn't have `s3:ListBucket` on the bucket ARN |
| `WebIdentityErr` | Trust policy `sub` is wrong namespace/SA |
| `expired token` | OIDC provider not registered in IAM (`eksctl utils associate-iam-oidc-provider`) |
