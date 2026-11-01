# GCP Infrastructure - Complete Execution Path

**Date**: 2025-12-10 (Updated)
**Purpose**: Define the exact order of operations to deploy GCP infrastructure from scratch

---

## OVERVIEW

The deployment is divided into 3 main phases:
1. **Terraform/Terragrunt** - Infrastructure provisioning
2. **Manual Bootstrap** - First-time runners setup (requires VPN)
3. **CI/CD Bootstrap** - Automated workloads cluster setup

---

## CURRENT STACK STRUCTURE

```
gameplatform-shared-infrastructure-gcp/
├── dev/
│   ├── 01-foundation/      # APIs, IAM
│   ├── 03-gke/             # GKE cluster (depends on nonprod/02)
│   ├── 04-database/        # Cloud SQL
│   ├── 05-dns-lb/          # DNS, Load Balancer
│   └── 06-workloads/       # Artifact Registry, OIDC
├── stg/
│   ├── 01-foundation/
│   ├── 03-gke/
│   ├── 04-database/
│   ├── 05-dns-lb/
│   └── 06-workloads/
├── nonprod/                 # SHARED resources for dev+stg
│   ├── 02-networking/       # Shared VPC for dev+stg+runners
│   ├── 07-vpn-bastion/      # Shared VPN/Bastion (NEW LOCATION)
│   └── 08-gke-runners/      # CI/CD runners cluster
└── prd/                     # ISOLATED production environment
    ├── 01-foundation/
    ├── 02-networking/       # Own VPC (not shared)
    ├── 03-gke/
    ├── 04-database/
    ├── 05-dns-lb/
    ├── 06-workloads/
    ├── 07-vpn-bastion/      # Own VPN/Bastion (not shared)
    └── 08-gke-runners/      # Own runners cluster (not shared)
```

---

## DEPENDENCY GRAPH

### NONPROD Project (dev + stg)

```
                 ┌─────────────────────┐
                 │   01-foundation     │ (dev AND stg - creates SA)
                 │   APIs, IAM         │
                 └─────────┬───────────┘
                           │
                           ▼
         ┌─────────────────────────────────────┐
         │        nonprod/02-networking        │
         │   VPC, Subnets, NAT, Firewall      │
         │   (shared by dev+stg+runners)      │
         └──────┬────────────┬────────────┬───┘
                │            │            │
                ▼            ▼            ▼
         ┌──────────┐  ┌──────────┐  ┌──────────────┐
         │ dev/03   │  │ stg/03   │  │ nonprod/08   │
         │   GKE    │  │   GKE    │  │ GKE-Runners  │
         └────┬─────┘  └────┬─────┘  └──────────────┘
              │             │
              ▼             ▼
         ┌──────────┐  ┌──────────┐
         │ dev/04   │  │ stg/04   │
         │ Database │  │ Database │
         └────┬─────┘  └────┬─────┘
              │             │
              ▼             ▼
         ┌──────────┐  ┌──────────┐
         │ dev/05   │  │ stg/05   │
         │ DNS/LB   │  │ DNS/LB   │
         └────┬─────┘  └────┬─────┘
              │             │
              ▼             ▼
         ┌──────────┐  ┌──────────┐
         │ dev/06   │  │ stg/06   │
         │ Workloads│  │ Workloads│
         └──────────┘  └──────────┘

         ┌─────────────────────────────────────┐
         │        nonprod/07-vpn-bastion       │
         │   WireGuard VPN, Bastion Host      │
         │   (shared, depends on networking)  │
         └─────────────────────────────────────┘
```

### PRD Project (isolated)

```
         ┌─────────────────────┐
         │   01-foundation     │
         │   APIs, IAM         │
         └─────────┬───────────┘
                   │
                   ▼
         ┌─────────────────────┐
         │   02-networking     │
         │   Own VPC           │
         └─────────┬───────────┘
                   │
         ┌─────────┴─────────┐
         ▼                   ▼
    ┌──────────┐       ┌──────────────┐
    │ 03-gke   │       │ 08-runners   │
    │ Workloads│       │ CI/CD        │
    └────┬─────┘       └──────────────┘
         │
         ▼
    ┌──────────┐
    │ 04-db    │
    └────┬─────┘
         │
         ▼
    ┌──────────┐
    │ 05-dns   │
    └────┬─────┘
         │
         ▼
    ┌──────────┐
    │ 06-work  │
    └──────────┘

    ┌──────────────────────┐
    │   07-vpn-bastion     │
    │   Own VPN/Bastion    │
    └──────────────────────┘
```

---

## PHASE 1: TERRAFORM EXECUTION ORDER

### For NONPROD (dev + stg)

Execute in this **exact order**:

```bash
cd /repos/gameplatform-shared-infrastructure-gcp

# ============================================================================
# STEP 1: Foundation (can run dev and stg in parallel)
# ============================================================================
# Creates: APIs, IAM roles, Service Accounts

cd dev/01-foundation && terragrunt apply -auto-approve && cd ../..
cd stg/01-foundation && terragrunt apply -auto-approve && cd ../..

# ============================================================================
# STEP 2: Shared Networking
# ============================================================================
# Creates: VPC, Subnets (dev, stg, runners), NAT Gateway, Firewall rules
# PREREQUISITE: dev/01-foundation (for project APIs)

cd nonprod/02-networking && terragrunt apply -auto-approve && cd ../..

# ============================================================================
# STEP 3: GKE Clusters (can run dev, stg, runners in parallel)
# ============================================================================
# Creates: GKE clusters (private, no public endpoint)
# PREREQUISITE: nonprod/02-networking

cd dev/03-gke && terragrunt apply -auto-approve && cd ../..
cd stg/03-gke && terragrunt apply -auto-approve && cd ../..
cd nonprod/08-gke-runners && terragrunt apply -auto-approve && cd ../..

# ============================================================================
# STEP 4: Databases (can run dev and stg in parallel)
# ============================================================================
# Creates: Cloud SQL instances, databases, users, secrets
# PREREQUISITE: nonprod/02-networking

cd dev/04-database && terragrunt apply -auto-approve && cd ../..
cd stg/04-database && terragrunt apply -auto-approve && cd ../..

# ============================================================================
# STEP 5: DNS and Load Balancer (can run dev and stg in parallel)
# ============================================================================
# Creates: Private DNS zones, internal load balancer
# PREREQUISITE: dev/03-gke, stg/03-gke

cd dev/05-dns-lb && terragrunt apply -auto-approve && cd ../..
cd stg/05-dns-lb && terragrunt apply -auto-approve && cd ../..

# ============================================================================
# STEP 6: Workloads Support (can run dev and stg in parallel)
# ============================================================================
# Creates: Artifact Registry, GitHub OIDC, ESO Service Accounts
# PREREQUISITE: dev/03-gke, stg/03-gke

cd dev/06-workloads && terragrunt apply -auto-approve && cd ../..
cd stg/06-workloads && terragrunt apply -auto-approve && cd ../..

# ============================================================================
# STEP 7: VPN/Bastion (SHARED for nonprod)
# ============================================================================
# Creates: WireGuard VPN Gateway, Bastion Host
# PREREQUISITE: nonprod/02-networking

cd nonprod/07-vpn-bastion && terragrunt apply -auto-approve && cd ../..
```

### For PRD (isolated)

```bash
cd /repos/gameplatform-shared-infrastructure-gcp

# ============================================================================
# STEP 1: Foundation
# ============================================================================
cd prd/01-foundation && terragrunt apply -auto-approve && cd ../..

# ============================================================================
# STEP 2: Networking (own VPC)
# ============================================================================
cd prd/02-networking && terragrunt apply -auto-approve && cd ../..

# ============================================================================
# STEP 3: GKE Clusters (can run workloads and runners in parallel)
# ============================================================================
cd prd/03-gke && terragrunt apply -auto-approve && cd ../..
cd prd/08-gke-runners && terragrunt apply -auto-approve && cd ../..

# ============================================================================
# STEP 4: Database
# ============================================================================
cd prd/04-database && terragrunt apply -auto-approve && cd ../..

# ============================================================================
# STEP 5: DNS and Load Balancer
# ============================================================================
cd prd/05-dns-lb && terragrunt apply -auto-approve && cd ../..

# ============================================================================
# STEP 6: Workloads Support
# ============================================================================
cd prd/06-workloads && terragrunt apply -auto-approve && cd ../..

# ============================================================================
# STEP 7: VPN/Bastion (own, not shared)
# ============================================================================
cd prd/07-vpn-bastion && terragrunt apply -auto-approve && cd ../..
```

### Script for Full NONPROD Deploy

```bash
#!/bin/bash
# deploy-nonprod.sh

set -euo pipefail

BASE_DIR="/repos/gameplatform-shared-infrastructure-gcp"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

apply_stack() {
    local stack=$1
    log "Applying $stack..."
    cd "$BASE_DIR/$stack"
    terragrunt apply -auto-approve
    log "Completed $stack"
    cd "$BASE_DIR"
}

log "Starting NONPROD Terraform deployment..."

# Step 1: Foundation (parallel)
apply_stack "dev/01-foundation" &
apply_stack "stg/01-foundation" &
wait

# Step 2: Networking (sequential - shared resource)
apply_stack "nonprod/02-networking"

# Step 3: GKE (parallel)
apply_stack "dev/03-gke" &
apply_stack "stg/03-gke" &
apply_stack "nonprod/08-gke-runners" &
wait

# Step 4: Database (parallel)
apply_stack "dev/04-database" &
apply_stack "stg/04-database" &
wait

# Step 5: DNS/LB (parallel)
apply_stack "dev/05-dns-lb" &
apply_stack "stg/05-dns-lb" &
wait

# Step 6: Workloads (parallel)
apply_stack "dev/06-workloads" &
apply_stack "stg/06-workloads" &
wait

# Step 7: VPN (sequential)
apply_stack "nonprod/07-vpn-bastion"

log "NONPROD Terraform deployment complete!"
```

---

## PHASE 2: MANUAL BOOTSTRAP (Runners Cluster)

**REQUIRES**: VPN connection (after step 7 above)

This phase MUST be done manually because:
- Runners don't exist yet
- CI/CD can't run without runners
- Private clusters only accessible via VPN

### Steps for NONPROD

```bash
# ============================================================================
# STEP 8: Connect to VPN
# ============================================================================
# Get WireGuard config from bastion metadata
gcloud compute instances describe gameplatform-nonprod-bastion \
  --zone=us-east1-b \
  --project=project-nonprod-env \
  --format='get(metadata.items[wg-client-config])' > ~/wireguard-nonprod.conf

# Import config in WireGuard client and connect

# ============================================================================
# STEP 9: Create GitHub PAT Secret
# ============================================================================
# Create GitHub PAT with these scopes:
# - repo (full control)
# - admin:org -> Self-hosted runners (Read and Write)

gcloud secrets create github-arc-pat --project=project-nonprod-env 2>/dev/null || true
printf '%s' "YOUR_GITHUB_PAT_HERE" | gcloud secrets versions add github-arc-pat \
    --data-file=- --project=project-nonprod-env

# ============================================================================
# STEP 10: Bootstrap Runners Cluster
# ============================================================================
cd /repos/platform-kubernetes-infrastructure

# Connect to runners cluster
gcloud container clusters get-credentials gameplatform-nonprod-runners \
  --region us-east1 --project project-nonprod-env --internal-ip

# Install ESO
cd charts/external-secrets
./install.sh runners

# Install ARC
cd ../runners
./install.sh

# Verify runners appear in GitHub
# Go to: https://github.com/organizations/example-gamedev-org/settings/actions/runners
# Should see: gameplatform-light and gameplatform-heavy

cd /repos/platform-kubernetes-infrastructure
```

### Steps for PRD (when needed)

```bash
# Similar steps but with prd project
gcloud compute instances describe project-prd-bastion \
  --zone=southamerica-east1-a \
  --project=project-prd-env \
  --format='get(metadata.items[wg-client-config])' > ~/wireguard-prd.conf

# Connect to prd runners cluster
gcloud container clusters get-credentials project-prd-runners \
  --region southamerica-east1 --project project-prd-env --internal-ip

# Install ESO and ARC (same scripts, different cluster)
```

---

## PHASE 3: CI/CD BOOTSTRAP (Workloads Clusters)

**REQUIRES**: Runners active from Phase 2

Now that runners exist, use GitHub Actions workflow to bootstrap workloads clusters.

### Option A: Use Existing Workflow

```bash
# Trigger via GitHub UI:
# Repository: platform-kubernetes-infrastructure
# Actions → "Bootstrap Cluster" → Run workflow
# Select: dev-workloads
# Components: auto (ESO + ArgoCD)
# Dry run: No

# Repeat for stg-workloads
```

### Option B: Manual Bootstrap (Alternative)

```bash
# ============================================================================
# STEP 11: Bootstrap Dev Workloads Cluster
# ============================================================================
gcloud container clusters get-credentials project-dev-workloads \
  --region us-east1 --project project-nonprod-env --internal-ip

# Install ESO
cd /repos/platform-kubernetes-infrastructure
cd charts/external-secrets
./install.sh workloads

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Create workload namespace
kubectl create namespace gameplatform-dev

# ============================================================================
# STEP 12: Configure ArgoCD Repository Credentials
# ============================================================================
kubectl create secret generic argocd-repo-creds \
    -n argocd \
    --from-literal=url=https://github.com/example-gamedev-org/platform-kubernetes-infrastructure.git \
    --from-literal=username=YOUR_GITHUB_USERNAME \
    --from-literal=password=YOUR_GITHUB_PAT

kubectl label secret argocd-repo-creds -n argocd argocd.argoproj.io/secret-type=repository

# ============================================================================
# STEP 13: Create ArgoCD Application
# ============================================================================
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: game-platform-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example-gamedev-org/platform-kubernetes-infrastructure.git
    targetRevision: main
    path: charts/game-platform
    helm:
      valueFiles:
        - values.yaml
        - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: gameplatform-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# ============================================================================
# STEP 14: Repeat for STG
# ============================================================================
# (similar steps with stg cluster and values)
```

---

## PHASE 4: APPLICATION DEPLOYMENT

After all bootstrap complete:

### Build and Push Images

```bash
# Trigger via GitHub UI:
# Repository: gameplatform-monorepo
# Actions → "Build and Push to GCP"
# Select all services
# Tag: v1.0.0
```

### Verify Deployment

```bash
# Connect to dev cluster
gcloud container clusters get-credentials project-dev-workloads \
  --region us-east1 --project project-nonprod-env --internal-ip

# Check ArgoCD status
kubectl get applications -n argocd

# Check pods
kubectl get pods -n gameplatform-dev

# Check services
kubectl get svc -n gameplatform-dev
```

---

## COMPLETE EXECUTION CHECKLIST

### Pre-Flight
- [ ] GCP projects exist (project-nonprod-env, project-prd-env)
- [ ] Terraform state bucket exists
- [ ] gcloud authenticated
- [ ] GitHub PAT created with correct scopes

### Phase 1: Terraform (NONPROD)
- [ ] dev/01-foundation applied
- [ ] stg/01-foundation applied
- [ ] nonprod/02-networking applied
- [ ] dev/03-gke applied
- [ ] stg/03-gke applied
- [ ] nonprod/08-gke-runners applied
- [ ] dev/04-database applied
- [ ] stg/04-database applied
- [ ] dev/05-dns-lb applied
- [ ] stg/05-dns-lb applied
- [ ] dev/06-workloads applied
- [ ] stg/06-workloads applied
- [ ] nonprod/07-vpn-bastion applied

### Phase 1: Terraform (PRD) - When Ready
- [ ] prd/01-foundation applied
- [ ] prd/02-networking applied
- [ ] prd/03-gke applied
- [ ] prd/08-gke-runners applied
- [ ] prd/04-database applied
- [ ] prd/05-dns-lb applied
- [ ] prd/06-workloads applied
- [ ] prd/07-vpn-bastion applied

### Phase 2: Manual Bootstrap (NONPROD)
- [ ] VPN connected (nonprod)
- [ ] GitHub PAT secret created in GCP
- [ ] ESO installed on runners cluster
- [ ] ARC installed on runners cluster
- [ ] Runners visible in GitHub

### Phase 3: CI/CD Bootstrap
- [ ] ESO installed on dev-workloads
- [ ] ArgoCD installed on dev-workloads
- [ ] gameplatform-dev namespace created
- [ ] ArgoCD repo credentials configured
- [ ] ArgoCD Application created for dev
- [ ] (Repeat for stg)

### Phase 4: Application
- [ ] Images built and pushed
- [ ] ArgoCD synced applications
- [ ] Pods running in gameplatform-dev
- [ ] Services accessible via VPN

---

## DESTROY ORDER (Reverse)

### NONPROD Destroy

```bash
# Phase 4: Delete Applications
kubectl delete applications --all -n argocd

# Phase 3: Delete bootstrap components
kubectl delete ns argocd gameplatform-dev external-secrets

# Phase 2: Delete ARC
kubectl delete ns arc-systems arc-runners

# Phase 1: Terraform destroy (reverse order)
cd nonprod/07-vpn-bastion && terragrunt destroy -auto-approve && cd ../..
cd stg/06-workloads && terragrunt destroy -auto-approve && cd ../..
cd dev/06-workloads && terragrunt destroy -auto-approve && cd ../..
cd stg/05-dns-lb && terragrunt destroy -auto-approve && cd ../..
cd dev/05-dns-lb && terragrunt destroy -auto-approve && cd ../..
cd stg/04-database && terragrunt destroy -auto-approve && cd ../..
cd dev/04-database && terragrunt destroy -auto-approve && cd ../..
cd nonprod/08-gke-runners && terragrunt destroy -auto-approve && cd ../..
cd stg/03-gke && terragrunt destroy -auto-approve && cd ../..
cd dev/03-gke && terragrunt destroy -auto-approve && cd ../..
cd nonprod/02-networking && terragrunt destroy -auto-approve && cd ../..
cd stg/01-foundation && terragrunt destroy -auto-approve && cd ../..
cd dev/01-foundation && terragrunt destroy -auto-approve && cd ../..
```

### PRD Destroy

```bash
cd prd/07-vpn-bastion && terragrunt destroy -auto-approve && cd ../..
cd prd/06-workloads && terragrunt destroy -auto-approve && cd ../..
cd prd/05-dns-lb && terragrunt destroy -auto-approve && cd ../..
cd prd/04-database && terragrunt destroy -auto-approve && cd ../..
cd prd/08-gke-runners && terragrunt destroy -auto-approve && cd ../..
cd prd/03-gke && terragrunt destroy -auto-approve && cd ../..
cd prd/02-networking && terragrunt destroy -auto-approve && cd ../..
cd prd/01-foundation && terragrunt destroy -auto-approve && cd ../..
```

---

*Document created: 2025-12-10*
*Last updated: 2025-12-10 (07-vpn-bastion moved to nonprod, prd 07 and 08 created)*
