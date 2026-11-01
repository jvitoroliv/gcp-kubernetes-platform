# GCP Secret Manager Setup

This document lists all secrets that need to be created in GCP Secret Manager for each environment.

## Naming Convention

Secrets follow the pattern: `gameplatform-{env}-{service}-{secret-name}`

Examples:
- `project-dev-lobby-backend-database-url`
- `project-stg-nakama-server-key`
- `project-prd-aes-api-key`

## Secrets by Service

### lobby-backend

| Secret Name | Description |
|-------------|-------------|
| `gameplatform-{env}-lobby-backend-database-url` | PostgreSQL connection string |
| `gameplatform-{env}-nakama-server-key` | Nakama server authentication key |
| `gameplatform-{env}-nakama-http-key` | Nakama HTTP API key |
| `gameplatform-{env}-aes-api-key` | API key for AES (Email Service) |
| `gameplatform-{env}-aes-encryption-key` | AES encryption key |

### nakama

| Secret Name | Description |
|-------------|-------------|
| `gameplatform-{env}-nakama-database-url` | PostgreSQL connection string for Nakama |
| `gameplatform-{env}-nakama-server-key` | Server authentication key |
| `gameplatform-{env}-nakama-http-key` | HTTP API key |
| `gameplatform-{env}-aes-encryption-key` | AES encryption key (shared) |

### aes (Email Service)

| Secret Name | Description |
|-------------|-------------|
| `gameplatform-{env}-aes-api-key` | Internal API key |
| `gameplatform-{env}-smtp-user` | SMTP username |
| `gameplatform-{env}-smtp-password` | SMTP password |

### afs (Asset File Service)

| Secret Name | Description |
|-------------|-------------|
| `gameplatform-{env}-gcs-credentials` | GCS service account key (if not using Workload Identity) |

### ahsat (Analytics Service)

| Secret Name | Description |
|-------------|-------------|
| `gameplatform-{env}-nakama-http-key` | Nakama HTTP key for auth |
| `gameplatform-{env}-ahsat-database-url` | Database connection (if separate DB) |

### ais (AI Image Service)

| Secret Name | Description |
|-------------|-------------|
| `gameplatform-{env}-ais-app-secret` | Application secret |
| `gameplatform-{env}-piapi-api-key` | PiAPI API key |

### aps (Payment Service)

| Secret Name | Description |
|-------------|-------------|
| `gameplatform-{env}-yuno-public-key` | Yuno public API key |
| `gameplatform-{env}-yuno-private-key` | Yuno private API key |
| `gameplatform-{env}-yuno-account-id` | Yuno account ID |

### lobby (Frontend)

| Secret Name | Description |
|-------------|-------------|
| (None for now - frontend uses public env vars) | |

## Creating Secrets

### Using gcloud CLI

```bash
# Create a secret (use project-nonprod-env for dev/stg, project-prd-env for prd)
printf '%s' "your-secret-value" | gcloud secrets create project-dev-lobby-backend-database-url \
  --data-file=- \
  --project=project-nonprod-env \
  --replication-policy=automatic

# Add a new version to existing secret
printf '%s' "new-secret-value" | gcloud secrets versions add project-dev-lobby-backend-database-url \
  --data-file=- \
  --project=project-nonprod-env

# List secrets
gcloud secrets list --project=project-nonprod-env

# View secret value
gcloud secrets versions access latest --secret=project-dev-lobby-backend-database-url --project=project-nonprod-env
```

### Grant ESO Access

The External Secrets Operator service account needs access to read secrets:

```bash
# Grant access to ESO service account for workloads cluster
gcloud secrets add-iam-policy-binding project-dev-lobby-backend-database-url \
  --project=project-nonprod-env \
  --member="serviceAccount:project-dev-eso-workloads@project-nonprod-env.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

Or grant access to all secrets at once:

```bash
# Grant project-level access (simpler but less granular)
gcloud projects add-iam-policy-binding project-nonprod-env \
  --member="serviceAccount:project-dev-eso-workloads@project-nonprod-env.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

## DEV Environment Secrets

Run these commands to create all secrets for DEV:

```bash
# DEV/STG use project-nonprod-env, PRD uses project-prd-env
PROJECT=project-nonprod-env

# Database URLs (Note: created automatically by Terraform 04-database stack)
printf '%s' "postgresql://user:pass@host:5432/dbname" | gcloud secrets create project-dev-lobby-backend-database-url --data-file=- --project=$PROJECT --replication-policy=automatic
printf '%s' "postgres://user:pass@host:5432/nakama?sslmode=disable" | gcloud secrets create project-dev-nakama-database-url --data-file=- --project=$PROJECT --replication-policy=automatic

# Nakama keys
printf '%s' "your-server-key" | gcloud secrets create project-dev-nakama-server-key --data-file=- --project=$PROJECT --replication-policy=automatic
printf '%s' "your-http-key" | gcloud secrets create project-dev-nakama-http-key --data-file=- --project=$PROJECT --replication-policy=automatic

# AES keys
printf '%s' "your-aes-api-key" | gcloud secrets create project-dev-aes-api-key --data-file=- --project=$PROJECT --replication-policy=automatic
printf '%s' "your-aes-encryption-key" | gcloud secrets create project-dev-aes-encryption-key --data-file=- --project=$PROJECT --replication-policy=automatic

# SMTP credentials
printf '%s' "smtp-username" | gcloud secrets create project-dev-smtp-user --data-file=- --project=$PROJECT --replication-policy=automatic
printf '%s' "smtp-password" | gcloud secrets create project-dev-smtp-password --data-file=- --project=$PROJECT --replication-policy=automatic

# AIS keys
printf '%s' "your-ais-app-secret" | gcloud secrets create project-dev-ais-app-secret --data-file=- --project=$PROJECT --replication-policy=automatic
printf '%s' "your-piapi-key" | gcloud secrets create project-dev-piapi-api-key --data-file=- --project=$PROJECT --replication-policy=automatic

# APS/Yuno keys
printf '%s' "yuno-public-key" | gcloud secrets create project-dev-yuno-public-key --data-file=- --project=$PROJECT --replication-policy=automatic
printf '%s' "yuno-private-key" | gcloud secrets create project-dev-yuno-private-key --data-file=- --project=$PROJECT --replication-policy=automatic
printf '%s' "yuno-account-id" | gcloud secrets create project-dev-yuno-account-id --data-file=- --project=$PROJECT --replication-policy=automatic
```

## Verifying Secrets

After creating secrets, verify they're accessible:

```bash
# Check if ESO can sync secrets
kubectl get externalsecret -n gameplatform

# Check secret status
kubectl describe externalsecret lobby-backend-secrets -n gameplatform

# View synced secret (base64 encoded)
kubectl get secret lobby-backend-secrets -n gameplatform -o yaml
```
