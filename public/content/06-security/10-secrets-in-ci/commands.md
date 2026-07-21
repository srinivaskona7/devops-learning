# Secrets in CI (OIDC to Cloud) — Commands

> Quick pickup reference. Pair with `README.md` for theory.

## Setup

```bash
# AWS — register GitHub as an OIDC provider (once per account)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# GCP — Workload Identity Pool + Provider
gcloud iam workload-identity-pools create github-pool \
  --location=global --display-name="GitHub Actions"
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location=global --workload-identity-pool=github-pool \
  --issuer-uri=https://token.actions.githubusercontent.com \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository"

# Azure — federated credential
az ad app federated-credential create --id <app-id> --parameters '{
  "name":"gh-main",
  "issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:org/repo:ref:refs/heads/main",
  "audiences":["api://AzureADTokenExchange"]
}'
```

## Apply policies / manifests

```bash
# AWS — IAM role with trust policy pinned to the repo+branch
aws iam create-role --role-name github-deploy \
  --assume-role-policy-document file://trust.json
# trust.json — see github-oidc-aws.yaml in this folder
aws iam put-role-policy --role-name github-deploy \
  --policy-name s3-write \
  --policy-document file://permissions.json

# GCP — bind service account to a workload identity principal
gcloud iam service-accounts add-iam-policy-binding \
  github-deploy@PROJECT.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUM/locations/global/workloadIdentityPools/github-pool/attribute.repository/org/repo"

# Vault — JWT auth
vault auth enable jwt
vault write auth/jwt/config oidc_discovery_url=https://token.actions.githubusercontent.com
vault write auth/jwt/role/github \
  bound_audiences=https://github.com/org \
  bound_claims='{"repository":"org/repo","ref":"refs/heads/main"}' \
  user_claim=actor token_policies=deploy
```

## Inspect / verify

```bash
# AWS — list OIDC providers
aws iam list-open-id-connect-providers

# Show role trust policy
aws iam get-role --role-name github-deploy --query Role.AssumeRolePolicyDocument

# Test the assumption locally with a token (rare; usually only inside Actions)
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::123:role/github-deploy \
  --role-session-name test \
  --web-identity-token "$JWT"

# CloudTrail event for the assumed role call
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity

# Decode the JWT GH Actions issues (debug step in workflow)
# - run: echo "$ACTIONS_ID_TOKEN_REQUEST_TOKEN" | cut -d. -f2 | base64 -d | jq .
```

## Common operations

```bash
# In a GitHub Actions workflow:
# permissions:
#   id-token: write   # REQUIRED — opt-in to OIDC token issuance
#   contents: read

# - uses: aws-actions/configure-aws-credentials@v4
#   with:
#     role-to-assume: arn:aws:iam::123:role/github-deploy
#     aws-region: us-east-1
# - run: aws s3 ls

# Tighten subject claim — only deploy from main branch
# trust policy condition:
#   "token.actions.githubusercontent.com:sub":
#       "repo:org/repo:ref:refs/heads/main"

# Even tighter: require GH Environment with manual approval
#   "repo:org/repo:environment:production"
```

## Cleanup

```bash
aws iam delete-role-policy --role-name github-deploy --policy-name s3-write
aws iam delete-role --role-name github-deploy
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::123:oidc-provider/token.actions.githubusercontent.com

gcloud iam workload-identity-pools delete github-pool --location=global
```

## One-liners worth memorising

```bash
# Generate the GH Actions OIDC thumbprint (rotates rarely)
openssl s_client -servername token.actions.githubusercontent.com \
  -showcerts -connect token.actions.githubusercontent.com:443 < /dev/null 2>/dev/null \
  | openssl x509 -in /dev/stdin -fingerprint -sha1 -noout

# Audit which repos can assume which roles
aws iam list-roles --query 'Roles[?AssumeRolePolicyDocument!=null].[RoleName,AssumeRolePolicyDocument]' --output json

# Block PRs from assuming prod role: condition on subject claim
#   "StringNotLike": { "...:sub": "repo:org/repo:pull_request" }
```
