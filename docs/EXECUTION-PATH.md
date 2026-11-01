# GamePlatform GCP Infrastructure - Execution Path

**Date**: 2025-12-11
**Status**: Complete Guide for Environment Recreation

---

## Overview

This document provides the complete execution path to deploy the GamePlatform platform on GCP from scratch. Follow each phase in order.

**IMPORTANT**: ALL Terraform/Terragrunt execution is done via GitHub Actions Workflows. NO local terragrunt commands.

### Architecture Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        GCP Project: project-nonprod-env                       │
│                              Region: us-east1                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    SHARED VPC: gameplatform-nonprod-vpc                    │   │
│  │                                                                       │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐  │   │
│  │  │ DEV Subnet      │  │ STG Subnet      │  │ RUNNERS Subnet      │  │   │
│  │  │ 10.100.0.0/20   │  │ 10.48.0.0/20    │  │ 10.120.0.0/20       │  │   │
│  │  │                 │  │                 │  │                     │  │   │
│  │  │ project-dev-     │  │ project-stg-     │  │ gameplatform-nonprod-     │  │   │
│  │  │ workloads       │  │ workloads       │  │ runners             │  │   │
│  │  │ (GKE)           │  │ (GKE)           │  │ (GKE)               │  │   │
│  │  │                 │  │                 │  │                     │  │   │
│  │  │ - Namespace:    │  │ - Namespace:    │  │ - ArgoCD            │  │   │
│  │  │   gameplatform-dev    │  │   gameplatform-stg    │  │ - ARC Controller    │  │   │
│  │  │ - ESO           │  │ - ESO           │  │ - ARC Runners       │  │   │
│  │  │ - Services      │  │ - Services      │  │ - ESO               │  │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────┘  │   │
│  │                                                                       │   │
│  │  ┌───────────────────────────────────────────────────────────────┐   │   │
│  │  │ Cloud SQL: project-dev-postgres, postgres-stg                  │   │   │
│  │  │ Cloud DNS: *.dev.gameplatform (internal), *.stg.gameplatform (internal)   │   │   │
│  │  │ Cloud NAT: Outbound internet access                           │   │   │
│  │  │ WireGuard VPN: Bastion host for admin access                  │   │   │
│  │  └───────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Points

- **ArgoCD runs on `gameplatform-nonprod-runners`** and manages dev + stg clusters remotely
- **ARC (Actions Runner Controller) runs on `gameplatform-nonprod-runners`**
- **ESO is installed on ALL clusters**
- **Clusters are PRIVATE** - requires VPN for access
- **Terraform/Terragrunt runs via GitHub Actions Workflows ONLY**

---

## Phase 0: Prerequisites (ONE-TIME SETUP)

### 0.1 GCP Project Setup

Create projects in GCP Console:
- `project-nonprod-env` (for dev, stg, nonprod)
- `project-prd-env` (for production - when needed)

### 0.2 Enable Required APIs

```bash
# Run in Cloud Shell or local terminal with owner permissions
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  sqladmin.googleapis.com \
  servicenetworking.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com \
  dns.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  --project=project-nonprod-env
```

### 0.3 Create Terraform State Bucket

```bash
# NONPROD State Bucket (for dev, stg, and nonprod shared resources)
gsutil mb -p project-nonprod-env -l us-east1 gs://gameplatform-nonprod-terraform-state
gsutil versioning set on gs://gameplatform-nonprod-terraform-state

# PRD State Bucket (create when setting up production)
# gsutil mb -p project-prd-env -l southamerica-east1 gs://project-prd-terraform-state
# gsutil versioning set on gs://project-prd-terraform-state
```

### 0.4 Setup GitHub Actions OIDC Authentication (CRITICAL)

This enables GitHub Actions to authenticate to GCP without service account keys.

```bash
# =============================================================================
# STEP 1: Create Service Account
# =============================================================================
gcloud iam service-accounts create gameplatform-nonprod-github-actions \
  --display-name="GitHub Actions Service Account" \
  --description="Service account for GitHub Actions CI/CD" \
  --project=project-nonprod-env

# =============================================================================
# STEP 2: Create Workload Identity Pool
# =============================================================================
gcloud iam workload-identity-pools create gameplatform-nonprod-github-pool \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --description="Workload Identity Pool for GitHub Actions" \
  --project=project-nonprod-env

# =============================================================================
# STEP 3: Create OIDC Provider
# =============================================================================
gcloud iam workload-identity-pools providers create-oidc github-oidc \
  --location="global" \
  --workload-identity-pool="gameplatform-nonprod-github-pool" \
  --display-name="GitHub OIDC Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == 'example-gamedev-org'" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --project=project-nonprod-env

# =============================================================================
# STEP 4: Grant Roles to Service Account
# =============================================================================
# Editor (general permissions)
gcloud projects add-iam-policy-binding project-nonprod-env \
  --member="serviceAccount:gameplatform-nonprod-github-actions@project-nonprod-env.iam.gserviceaccount.com" \
  --role="roles/editor"

# Service Account Admin (to manage other service accounts)
gcloud projects add-iam-policy-binding project-nonprod-env \
  --member="serviceAccount:gameplatform-nonprod-github-actions@project-nonprod-env.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountAdmin"

# Service Networking Admin (for VPC peering with Cloud SQL)
gcloud projects add-iam-policy-binding project-nonprod-env \
  --member="serviceAccount:gameplatform-nonprod-github-actions@project-nonprod-env.iam.gserviceaccount.com" \
  --role="roles/servicenetworking.networksAdmin"

# Secret Manager Admin (to create secrets)
gcloud projects add-iam-policy-binding project-nonprod-env \
  --member="serviceAccount:gameplatform-nonprod-github-actions@project-nonprod-env.iam.gserviceaccount.com" \
  --role="roles/secretmanager.admin"

# Project IAM Admin (to manage IAM bindings)
gcloud projects add-iam-policy-binding project-nonprod-env \
  --member="serviceAccount:gameplatform-nonprod-github-actions@project-nonprod-env.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"

# Storage Admin (for Terraform state)
gcloud projects add-iam-policy-binding project-nonprod-env \
  --member="serviceAccount:gameplatform-nonprod-github-actions@project-nonprod-env.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# =============================================================================
# STEP 5: Allow GitHub Actions to use the Service Account via Workload Identity
# =============================================================================
# Get project number first
PROJECT_NUMBER=$(gcloud projects describe project-nonprod-env --format='value(projectNumber)')
echo "Project Number: $PROJECT_NUMBER"

gcloud iam service-accounts add-iam-policy-binding \
  gameplatform-nonprod-github-actions@project-nonprod-env.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/gameplatform-nonprod-github-pool/attribute.repository_owner/example-gamedev-org" \
  --project=project-nonprod-env
```

### 0.5 Configure GitHub Repository Secrets/Variables

Go to GitHub Organization Settings > Secrets and Variables > Actions:

**Secrets:**
| Name | Value |
|------|-------|
| `GCP_SERVICE_ACCOUNT` | `gameplatform-nonprod-github-actions@project-nonprod-env.iam.gserviceaccount.com` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/gameplatform-nonprod-github-pool/providers/github-oidc` |

Replace `PROJECT_NUMBER` with the actual project number (e.g., `000000000000`).

### 0.6 Verify OIDC Configuration

```bash
# Verify service account exists
gcloud iam service-accounts list --project=project-nonprod-env --filter="email:github"

# Verify pool is ACTIVE (not DELETED)
gcloud iam workload-identity-pools describe gameplatform-nonprod-github-pool \
  --location="global" \
  --project=project-nonprod-env

# Verify provider exists
gcloud iam workload-identity-pools providers list \
  --workload-identity-pool="gameplatform-nonprod-github-pool" \
  --location="global" \
  --project=project-nonprod-env
```

### 0.7 Troubleshooting OIDC Issues

If GitHub Actions can't authenticate:

```bash
# Check if pool is deleted (soft delete)
gcloud iam workload-identity-pools describe gameplatform-nonprod-github-pool \
  --location="global" \
  --project=project-nonprod-env
# If state: DELETED, restore it:
gcloud iam workload-identity-pools undelete gameplatform-nonprod-github-pool \
  --location="global" \
  --project=project-nonprod-env

# Check service account IAM bindings
gcloud iam service-accounts get-iam-policy \
  gameplatform-nonprod-github-actions@project-nonprod-env.iam.gserviceaccount.com \
  --project=project-nonprod-env

# Re-add workload identity binding if missing
PROJECT_NUMBER=$(gcloud projects describe project-nonprod-env --format='value(projectNumber)')
gcloud iam service-accounts add-iam-policy-binding \
  gameplatform-nonprod-github-actions@project-nonprod-env.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/gameplatform-nonprod-github-pool/attribute.repository_owner/example-gamedev-org" \
  --project=project-nonprod-env
```

---

## Phase 1: Terraform Infrastructure (via GitHub Actions)

### 1.1 Terraform State Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│ gameplatform-nonprod-terraform-state (bucket in project-nonprod-env)           │
│ ├── dev/01-foundation/terraform.tfstate                                 │
│ ├── dev/03-gke/terraform.tfstate                                        │
│ ├── dev/04-database/terraform.tfstate                                   │
│ ├── stg/01-foundation/terraform.tfstate                                 │
│ ├── stg/03-gke/terraform.tfstate                                        │
│ ├── nonprod/02-networking/terraform.tfstate (shared VPC)                │
│ ├── nonprod/07-vpn-bastion/terraform.tfstate                            │
│ └── nonprod/08-gke-runners/terraform.tfstate                            │
└─────────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────────┐
│ project-prd-terraform-state (bucket in project-prd-env)                   │
│ ├── prd/01-foundation/terraform.tfstate                                 │
│ ├── prd/02-networking/terraform.tfstate                                 │
│ └── prd/.../terraform.tfstate                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Deploy via GitHub Actions Workflows

**Go to**: `gameplatform-shared-infrastructure-gcp` repository > Actions > Select Workflow

**Execution Order (CRITICAL - follow exactly):**

| Order | Workflow | Environment | Stack |
|-------|----------|-------------|-------|
| 1 | Terraform Apply | nonprod | 02-networking |
| 2 | Terraform Apply | dev | 01-foundation |
| 3 | Terraform Apply | dev | 03-gke |
| 4 | Terraform Apply | dev | 04-database |
| 5 | Terraform Apply | dev | 05-dns-lb |
| 6 | Terraform Apply | dev | 06-workloads |
| 7 | Terraform Apply | stg | 01-foundation |
| 8 | Terraform Apply | stg | 03-gke |
| 9 | Terraform Apply | stg | 04-database |
| 10 | Terraform Apply | stg | 05-dns-lb |
| 11 | Terraform Apply | stg | 06-workloads |
| 12 | Terraform Apply | nonprod | 07-vpn-bastion |
| 13 | Terraform Apply | nonprod | 08-gke-runners |

**How to run each workflow:**
1. Go to GitHub > gameplatform-shared-infrastructure-gcp > Actions
2. Select "Terraform Apply" workflow
3. Click "Run workflow"
4. Select:
   - Environment: `nonprod`, `dev`, or `stg`
   - Stack: `01-foundation`, `02-networking`, etc.
5. Click "Run workflow"
6. Wait for completion before running the next one

### 1.3 Verify Infrastructure

After all workflows complete:

```bash
# List all clusters
gcloud container clusters list --project project-nonprod-env

# Expected output:
# NAME                    LOCATION  STATUS
# project-dev-workloads    us-east1  RUNNING
# project-stg-workloads    us-east1  RUNNING
# gameplatform-nonprod-runners  us-east1  RUNNING

# List SQL instances
gcloud sql instances list --project project-nonprod-env

# List Artifact Registries
gcloud artifacts repositories list --project project-nonprod-env --location us-east1
```

---

## Phase 2: VPN Setup

### 2.1 Get WireGuard Configuration

```bash
# Get bastion IP
gcloud compute instances describe gameplatform-nonprod-bastion \
  --zone us-east1-b \
  --project project-nonprod-env \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)'

# SSH to bastion via IAP
gcloud compute ssh gameplatform-nonprod-bastion \
  --zone us-east1-b \
  --project project-nonprod-env \
  --tunnel-through-iap

# On bastion, create WireGuard user
sudo /etc/wireguard/add-user.sh yourname

# Get client config
sudo cat /etc/wireguard/clients/yourname.conf
```

### 2.2 Connect to VPN

1. Copy the WireGuard config to your local machine
2. Import into WireGuard client (macOS/Windows/Linux)
3. Connect to VPN
4. Verify connectivity:

```bash
# Test internal connectivity
ping 10.100.0.1  # Dev subnet gateway
```

---

## Phase 3: Create Secrets

### 3.1 Run Secrets Script

```bash
cd ~/Documents/GamePlatform/Repos/platform-kubernetes-infrastructure/scripts/bootstrap

# Create DEV secrets (values extracted from AWS terraform)
./01-create-secrets-dev.sh

# Create STG secrets
./01-create-secrets-stg.sh
```

### 3.2 Verify Secrets

```bash
# List all secrets
gcloud secrets list --project project-nonprod-env

# Expected: ~45+ secrets with prefix project-dev-* and project-stg-*
```

---

## Phase 4: Build Custom Runner Image

**IMPORTANT**: This must be done BEFORE bootstrapping the runners cluster.

The ARC runners use a custom Docker image (`gameplatform-runner`) with pre-installed tools:
- Node.js 20, Go 1.22, Python 3.11
- Docker CLI, gcloud, kubectl, helm
- Pre-cached npm dependencies for lobby and lobby-backend

### 4.1 Run Build Runner Image Workflow

**Go to**: `platform-kubernetes-infrastructure` repository > Actions > "Build Runner Image"

1. Click "Run workflow"
2. Select branch: `main`
3. Tag: `latest` (or leave default)
4. Click "Run workflow"
5. Wait for completion (~10-15 minutes)

**Prerequisites for workflow:**
- GitHub Secret `MONOREPO_PAT` must be set (PAT with access to gameplatform-monorepo)
- GitHub Variable `GCP_PROJECT_NUMBER` must be set (e.g., `000000000000`)

### 4.2 Verify Image

```bash
# List images in Artifact Registry
gcloud artifacts docker images list \
  us-east1-docker.pkg.dev/project-nonprod-env/gameplatform-nonprod-images \
  --project project-nonprod-env

# Expected: gameplatform-runner with tag 'latest'
```

### 4.3 Alternative: Build Locally (if workflow fails)

```bash
cd ~/Documents/GamePlatform/Repos/platform-kubernetes-infrastructure/images/runner

# Set monorepo path (for package.json files)
export MONOREPO_PATH=~/Documents/GamePlatform/Repos/gameplatform-monorepo

# Authenticate to Artifact Registry
gcloud auth configure-docker us-east1-docker.pkg.dev --quiet

# Build and push image
./build.sh --push
```

---

## Phase 5: Bootstrap Runners Cluster

**IMPORTANT**: This must be done MANUALLY via VPN (one-time setup).

### 5.1 Connect to Runners Cluster

```bash
# Connect via VPN (internal-ip flag for private cluster)
gcloud container clusters get-credentials gameplatform-nonprod-runners \
  --region us-east1 \
  --project project-nonprod-env \
  --internal-ip

# Verify connection
kubectl get nodes
```

### 5.2 Run Bootstrap Script

```bash
cd ~/Documents/GamePlatform/Repos/platform-kubernetes-infrastructure/scripts/bootstrap

# Bootstrap runners cluster (installs ESO, ARC, ArgoCD)
./02-bootstrap-runners.sh
```

### 5.3 Create GitHub ARC PAT Secret (REQUIRED BEFORE BOOTSTRAP)

The ARC (Actions Runner Controller) needs a GitHub PAT to register runners. This secret is NOT created by Terraform - it must be created manually.

```bash
# Create the GitHub PAT secret for ARC
# Replace <YOUR_GITHUB_PAT> with a PAT that has:
# - repo (full control)
# - admin:org (for org-level runners)
echo -n "<YOUR_GITHUB_PAT>" | gcloud secrets create gameplatform-nonprod-github-arc-pat \
  --data-file=- \
  --project=project-nonprod-env \
  --replication-policy="automatic"
```

### 5.4 Verify Helm Values are Correct

The bootstrap script uses Helm values files that configure:
- **ESO**: Uses `project-dev-eso-runners` SA with Workload Identity
- **ARC**: Controller and listeners run on `infra` node pool (no taints)
- **ClusterSecretStore**: Pre-configured with Workload Identity auth

Key files in `platform-kubernetes-infrastructure`:
- `charts/external-secrets/values-runners.yaml` - ESO config with correct SA
- `charts/external-secrets/cluster-secret-store-runners.yaml` - ClusterSecretStore with workloadIdentity
- `charts/runners/controller/values.yaml` - ARC controller on infra pool
- `charts/runners/runner-heavy/values.yaml` - Heavy runners config (uses custom `gameplatform-runner` image)

**IMPORTANT**: All infra workloads (ESO, ARC controller, listeners) use `nodeSelector: node_pool: infra` which schedules them on the infra node pool that has NO taints.

### 5.5 Verify Installation

```bash
# Check ESO
kubectl get pods -n external-secrets
kubectl get clustersecretstore

# Check ARC
kubectl get pods -n arc-systems
kubectl get pods -n arc-runners

# Check ArgoCD
kubectl get pods -n argocd

# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

---

## Phase 6: Bootstrap Workloads Clusters

### 6.1 Bootstrap DEV Workloads

```bash
# Connect to dev cluster
gcloud container clusters get-credentials project-dev-workloads \
  --region us-east1 \
  --project project-nonprod-env \
  --internal-ip

# Bootstrap
./03-bootstrap-workloads.sh dev
```

### 6.2 Bootstrap STG Workloads

```bash
# Connect to stg cluster
gcloud container clusters get-credentials project-stg-workloads \
  --region us-east1 \
  --project project-nonprod-env \
  --internal-ip

# Bootstrap
./03-bootstrap-workloads.sh stg
```

---

## Phase 7: Configure ArgoCD

### 7.1 Connect to Runners and Configure

```bash
# Connect back to runners cluster
gcloud container clusters get-credentials gameplatform-nonprod-runners \
  --region us-east1 \
  --project project-nonprod-env \
  --internal-ip

# Configure ArgoCD (adds repos, registers clusters, applies applications)
./04-configure-argocd.sh
```

### 7.2 Access ArgoCD UI

```bash
# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
# Username: admin
# Password: (from step 5.5)
```

---

## Phase 8: Build and Deploy Applications

### 8.1 Sync ConfigMaps

```bash
# Trigger sync-configmaps workflow in gameplatform-monorepo
# OR manually:

gcloud container clusters get-credentials project-dev-workloads \
  --region us-east1 --project project-nonprod-env --internal-ip

cd ~/Documents/GamePlatform/Repos/gameplatform-monorepo

for service in lobby lobby-backend nakama afs ahsat aes ais aps; do
  kubectl create configmap ${service}-config \
    --from-env-file=environment-variables/dev/${service}.env \
    -n gameplatform-dev \
    --dry-run=client -o yaml | kubectl apply -f -
done
```

### 8.2 Build Images

Trigger the `Build and Push to GCP` workflow in gameplatform-monorepo:
- Go to GitHub Actions
- Select "Build and Push to GCP"
- Run workflow with:
  - Environment: dev
  - Services: all (or specific services)

### 8.3 Verify Deployment

```bash
# Check ArgoCD sync status
argocd app list
argocd app get game-platform-dev

# Check pods
kubectl get pods -n gameplatform-dev

# Check services
kubectl get svc -n gameplatform-dev
```

---

## Phase 9: Verification Checklist

### Infrastructure
- [ ] 3 GKE clusters running (dev-workloads, stg-workloads, nonprod-runners)
- [ ] 2 Cloud SQL instances (dev, stg)
- [ ] VPN connected and working
- [ ] All subnets created

### Kubernetes
- [ ] ESO running on all 3 clusters
- [ ] ClusterSecretStore configured on all clusters
- [ ] ARC Controller running on runners cluster
- [ ] ARC Runners (heavy) registered in GitHub
- [ ] ArgoCD running on runners cluster
- [ ] ArgoCD managing dev and stg clusters

### Applications
- [ ] Secrets synced via ExternalSecrets
- [ ] ConfigMaps created for all services
- [ ] Images built and pushed to Artifact Registry
- [ ] Pods running in gameplatform-dev namespace
- [ ] Pods running in gameplatform-stg namespace

### CI/CD
- [ ] GitHub runners visible in organization settings
- [ ] Build workflow runs on gameplatform-heavy
- [ ] Deploy workflow triggers ArgoCD sync

---

## Quick Reference Commands

### Connect to Clusters (via VPN)

```bash
# Dev workloads
gcloud container clusters get-credentials project-dev-workloads \
  --region us-east1 --project project-nonprod-env --internal-ip

# Stg workloads
gcloud container clusters get-credentials project-stg-workloads \
  --region us-east1 --project project-nonprod-env --internal-ip

# Runners
gcloud container clusters get-credentials gameplatform-nonprod-runners \
  --region us-east1 --project project-nonprod-env --internal-ip
```

### ArgoCD

```bash
# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Sync applications
argocd app sync game-platform-dev
argocd app sync game-platform-stg

# Check status
argocd app list
argocd app get game-platform-dev --refresh
```

### Troubleshooting

```bash
# ESO issues
kubectl describe clustersecretstore gcp-secret-manager
kubectl describe externalsecret <name> -n <namespace>

# ARC issues
kubectl logs -n arc-systems -l app.kubernetes.io/name=gha-rs-controller
kubectl get autoscalingrunnersets -n arc-runners

# ArgoCD issues
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
argocd app get <app-name> --show-operation
```

---

## Destruction Order (via GitHub Actions)

If you need to destroy everything, run "Terraform Destroy" workflow in reverse order:

| Order | Environment | Stack |
|-------|-------------|-------|
| 1 | nonprod | 08-gke-runners |
| 2 | nonprod | 07-vpn-bastion |
| 3 | stg | 06-workloads |
| 4 | stg | 05-dns-lb |
| 5 | stg | 04-database |
| 6 | stg | 03-gke |
| 7 | stg | 01-foundation |
| 8 | dev | 06-workloads |
| 9 | dev | 05-dns-lb |
| 10 | dev | 04-database |
| 11 | dev | 03-gke |
| 12 | dev | 01-foundation |
| 13 | nonprod | 02-networking |

---

## Appendix A: Runners Cluster Node Pool Architecture

The runners cluster has 2 node pools:

| Pool | Purpose | Taints | Workloads |
|------|---------|--------|-----------|
| **infra** | Infrastructure workloads | **NONE** | ArgoCD, ESO, ARC Controller, Listeners |
| **heavy** | All CI jobs | `runner-type=heavy:NoSchedule` | Docker builds, tests, linting |

**IMPORTANT**: The `infra` pool has NO taints, so ArgoCD, ESO, and ARC controller can schedule without tolerations.

**NOTE**: Heavy runners use the custom `gameplatform-runner` image which includes Node.js, Go, Python, Docker CLI, gcloud, kubectl, and helm pre-installed.

---

## Appendix B: Troubleshooting Bootstrap Issues

### ESO Pods Pending

If ESO pods are stuck in `Pending` state:

```bash
# Check pod scheduling issues
kubectl describe pod -n external-secrets -l app.kubernetes.io/name=external-secrets | grep -A5 Events

# Verify infra nodes exist with correct labels
kubectl get nodes -l node_pool=infra

# If no nodes with label, check all node labels
kubectl get nodes --show-labels | grep infra
```

### ClusterSecretStore InvalidProviderConfig

If ClusterSecretStore shows `STATUS=InvalidProviderConfig`:

```bash
# Check SA annotation is correct
kubectl get sa external-secrets -n external-secrets -o yaml | grep -A2 annotations

# Should show:
# iam.gke.io/gcp-service-account: project-dev-eso-runners@project-nonprod-env.iam.gserviceaccount.com

# If wrong, fix it:
kubectl annotate serviceaccount external-secrets -n external-secrets \
  iam.gke.io/gcp-service-account=project-dev-eso-runners@project-nonprod-env.iam.gserviceaccount.com \
  --overwrite

# Restart ESO
kubectl rollout restart deployment -n external-secrets --all
```

### ARC Listener Pending

If ARC listener pods are stuck in `Pending`:

```bash
# Check which node pool the listener is trying to schedule on
kubectl describe pod -n arc-systems -l app.kubernetes.io/component=runner-scale-set-listener | grep -A5 Events

# Verify listeners use infra nodeSelector
helm get values arc-runner-light -n arc-runners | grep -A3 nodeSelector
```

### Re-bootstrapping After Failure

If bootstrap fails midway and you need to clean up:

```bash
# Uninstall all Helm releases
helm uninstall external-secrets -n external-secrets 2>/dev/null || true
helm uninstall arc -n arc-systems 2>/dev/null || true
helm uninstall arc-runner-heavy -n arc-runners 2>/dev/null || true

# Delete ClusterSecretStore
kubectl delete clustersecretstore gcp-secret-manager 2>/dev/null || true

# Delete ArgoCD namespace (will delete all ArgoCD resources)
kubectl delete namespace argocd 2>/dev/null || true

# Re-run bootstrap
./02-bootstrap-runners.sh
```

---

*Document created: 2025-12-10*
*Last updated: 2025-12-11*
