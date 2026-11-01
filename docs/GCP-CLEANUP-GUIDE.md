# GCP Infrastructure Cleanup and Rebuild Guide

**Date**: 2025-12-10
**Status**: PENDING CLEANUP AND REBUILD

---

## Executive Summary

This document details the complete cleanup and rebuild plan for the GamePlatform GCP infrastructure. The current implementation has significant naming inconsistencies and structural issues that need to be fixed from scratch.

---

## 1. CURRENT PROBLEMS IDENTIFIED

### 1.1 Artifact Registry Naming Disaster

**Current State (WRONG)**:
```
us-east1-docker.pkg.dev/project-nonprod-env/project-dev-gameplatform     # WTF is "project-dev-gameplatform"?
us-east1-docker.pkg.dev/project-nonprod-env/project-dev-images     # This is for runners
us-east1-docker.pkg.dev/project-nonprod-env/project-stg-gameplatform     # Same garbage pattern
```

**Expected (CORRECT - following AWS ECR pattern)**:
```
# AWS ECR Reference (per service, per account):
777777777771.dkr.ecr.us-east-1.amazonaws.com/gameplatform-aes:dev-1.1.5.1
777777777771.dkr.ecr.us-east-1.amazonaws.com/gameplatform-lobby:dev-1.1.6.5
777777777775.dkr.ecr.us-east-1.amazonaws.com/gameplatform-lobby:stg-1.1.5.0.1
777777777772.dkr.ecr.sa-east-1.amazonaws.com/gameplatform-lobby:live-1.1.5.0.2
```

**Proposed GCP Structure (CORRECT)**:
```
# nonprod project (dev + stg)
us-east1-docker.pkg.dev/project-nonprod-env/project-dev-images     # Dev service images
us-east1-docker.pkg.dev/project-nonprod-env/project-stg-images     # Stg service images
us-east1-docker.pkg.dev/project-nonprod-env/gameplatform-nonprod-images # Shared (runners, tools)

# prd project
southamerica-east1-docker.pkg.dev/project-prd-env/project-prd-images   # Prd service images
southamerica-east1-docker.pkg.dev/project-prd-env/project-prd-shared   # Prd runners, tools
```

### 1.2 Terraform/Terragrunt Code Issues

The 06-workloads stack creates registries using a map:
```hcl
artifact_registries = {
  gameplatform = { ... }   # Creates "gameplatform-{env}-gameplatform" - STUPID
  images = { ... }   # Creates "gameplatform-{env}-images" - OK
}
```

**Fix Required**: Change the naming convention in the Terraform module or inputs.

### 1.3 References Across Repositories (All Need Fixing)

| Repository | Files with Wrong Registry References |
|------------|-------------------------------------|
| platform-kubernetes-infrastructure | ~20 files (workflows, charts, scripts) |
| gameplatform-monorepo | ~5 files (workflows) |
| gameplatform-shared-infrastructure-gcp | ~3 files (terragrunt.hcl) |
| gameplatform-shared-actions | TBD |

---

## 2. WHAT EXISTS IN GCP NOW (TO BE DESTROYED)

### 2.1 Project: project-nonprod-env

**GKE Clusters**:
- `project-dev-workloads` (us-east1) - PRIVATE
- `project-stg-workloads` (us-east1) - PRIVATE
- `gameplatform-nonprod-runners` (us-east1) - PRIVATE

**Cloud SQL**:
- `project-dev-postgres` (us-east1)
- `project-stg-postgres` (us-east1)

**Artifact Registry** (with wrong names):
- `project-dev-gameplatform` (should be `project-dev-images`)
- `project-dev-images` (should be `gameplatform-nonprod-images`)
- `project-stg-gameplatform` (should be `project-stg-images`)

**VPC**:
- `gameplatform-nonprod-vpc` (shared by dev, stg, runners)

**DNS Zones** (internal):
- `dev.gameplatform` (private)
- `stg.gameplatform` (private)

**VPN/Bastion**:
- `gameplatform-nonprod-bastion` (WireGuard VPN)

**Secret Manager** (21 secrets for dev):
- `project-dev-*` (nakama-http-key, db-host, etc.)

**Workload Identity**:
- GitHub OIDC pool and provider
- Service accounts for GitHub Actions, ESO

### 2.2 Project: project-prd-env

**Status**: NOT YET DEPLOYED (only foundation)

---

## 3. KUBERNETES BOOTSTRAP COMPONENTS (TO BE RECREATED)

Components that were installed manually and need scripts:

### 3.1 Cluster: gameplatform-nonprod-runners

| Component | Namespace | Status | Needs Script |
|-----------|-----------|--------|--------------|
| ARC Controller | arc-systems | Installed | YES |
| ARC Runner Scale Set (gameplatform-heavy) | arc-runners | Installed | YES |
| ESO | external-secrets | Installed | YES |
| ClusterSecretStore | cluster-scoped | Configured | YES |
| ExternalSecret (arc-github-secret) | arc-runners | Configured | YES |

### 3.2 Cluster: project-dev-workloads

| Component | Namespace | Status | Needs Script |
|-----------|-----------|--------|--------------|
| ArgoCD | argocd | Installed | YES |
| ESO | external-secrets | Installed | YES |
| ClusterSecretStore | cluster-scoped | Configured | YES |
| Namespace gameplatform-dev | - | Created | YES |
| ArgoCD Application | argocd | Created | YES |

### 3.3 Cluster: project-stg-workloads

| Component | Namespace | Status | Needs Script |
|-----------|-----------|--------|--------------|
| ArgoCD | argocd | NOT INSTALLED | YES |
| ESO | external-secrets | NOT INSTALLED | YES |
| ClusterSecretStore | cluster-scoped | NOT CONFIGURED | YES |
| Namespace gameplatform-stg | - | NOT CREATED | YES |

---

## 4. SECRETS TO BE RECREATED

### 4.1 GCP Secret Manager Secrets (project-nonprod-env)

**Created by Terraform (04-database)**:
- project-dev-db-host
- project-dev-db-nakama-connection
- project-dev-db-nakama-password
- project-dev-db-lobby-connection
- project-dev-db-lobby-password

**Created Manually (need script)**:
- project-dev-nakama-http-key
- project-dev-nakama-server-key
- project-dev-aes-encryption-key
- project-dev-nextauth-secret
- project-dev-google-client-id
- project-dev-google-client-secret
- project-dev-aes-api-key
- project-dev-smtp-user
- project-dev-smtp-password
- project-dev-ai-api-key
- project-dev-ais-app-secret
- project-dev-piapi-key
- project-dev-gemini-api-key
- project-dev-yuno-public-key
- project-dev-yuno-private-key
- project-dev-yuno-account-id
- project-dev-gcs-access-key (placeholder)
- project-dev-gcs-secret-key (placeholder)
- github-arc-pat (for ARC)

---

## 5. DESTRUCTION ORDER

**IMPORTANT**: Destroy in reverse dependency order!

### 5.1 Nonprod Environment (dev + stg)

```bash
# Connect to VPN first!

# 1. Delete K8s resources manually (ArgoCD apps, etc)
gcloud container clusters get-credentials project-dev-workloads --region us-east1 --project project-nonprod-env --internal-ip
kubectl delete applications --all -n argocd
kubectl delete ns argocd gameplatform-dev external-secrets

gcloud container clusters get-credentials project-stg-workloads --region us-east1 --project project-nonprod-env --internal-ip
kubectl delete ns gameplatform-stg external-secrets 2>/dev/null

gcloud container clusters get-credentials gameplatform-nonprod-runners --region us-east1 --project project-nonprod-env --internal-ip
kubectl delete ns arc-systems arc-runners external-secrets

# 2. Destroy Terraform stacks (reverse order)
cd /repos/gameplatform-shared-infrastructure-gcp

# nonprod shared
cd nonprod/08-gke-runners && terragrunt destroy -auto-approve && cd ../..
cd nonprod/07-vpn-bastion && terragrunt destroy -auto-approve && cd ../..

# dev
cd dev/06-workloads && terragrunt destroy -auto-approve && cd ../..
cd dev/05-dns-lb && terragrunt destroy -auto-approve && cd ../..
cd dev/04-database && terragrunt destroy -auto-approve && cd ../..
cd dev/03-gke && terragrunt destroy -auto-approve && cd ../..

# stg
cd stg/06-workloads && terragrunt destroy -auto-approve && cd ../..
cd stg/05-dns-lb && terragrunt destroy -auto-approve && cd ../..
cd stg/04-database && terragrunt destroy -auto-approve && cd ../..
cd stg/03-gke && terragrunt destroy -auto-approve && cd ../..

# nonprod networking (last)
cd nonprod/02-networking && terragrunt destroy -auto-approve && cd ../..

# DON'T destroy 01-foundation (APIs, IAM)
```

---

## 6. CORRECTIONS REQUIRED BEFORE REBUILD

### 6.1 Terraform Changes

**File**: `stacks/06-workloads/main.tf`

Change the artifact registry naming from:
```hcl
repository_id = "${local.name_prefix}-${each.key}"
```
To use the correct convention (or change inputs).

**File**: `dev/06-workloads/terragrunt.hcl`

Change:
```hcl
artifact_registries = {
  gameplatform = { ... }  # Creates project-dev-gameplatform
  images = { ... }  # Creates project-dev-images
}
```
To:
```hcl
artifact_registries = {
  images = {        # Creates project-dev-images (for services)
    description = "GamePlatform service container images - dev"
    ...
  }
}
```

For nonprod shared images (runners), create in nonprod/06-workloads or similar.

### 6.2 Kubernetes Infrastructure Changes

All files referencing wrong registry names need to be updated:
- charts/game-platform/values*.yaml
- charts/services/*/values.yaml
- .github/workflows/*.yml
- scripts/*.sh
- kustomize/overlays/*

### 6.3 Monorepo Changes

All workflows referencing wrong registry names:
- .github/workflows/build-and-push-gcp.yml
- .github/workflows/auto-build-gcp.yml

---

## 7. REBUILD ORDER

After corrections, rebuild in this order:

```bash
# 1. nonprod networking (shared VPC)
cd nonprod/02-networking && terragrunt apply -auto-approve && cd ../..

# 2. dev foundation (if not exists)
cd dev/01-foundation && terragrunt apply -auto-approve && cd ../..

# 3. dev GKE
cd dev/03-gke && terragrunt apply -auto-approve && cd ../..

# 4. dev database
cd dev/04-database && terragrunt apply -auto-approve && cd ../..

# 5. dev DNS/LB
cd dev/05-dns-lb && terragrunt apply -auto-approve && cd ../..

# 6. dev workloads (artifact registry, OIDC, ESO SA)
cd dev/06-workloads && terragrunt apply -auto-approve && cd ../..

# 7. nonprod VPN
cd nonprod/07-vpn-bastion && terragrunt apply -auto-approve && cd ../..

# 8. nonprod runners cluster
cd nonprod/08-gke-runners && terragrunt apply -auto-approve && cd ../..

# Repeat 2-6 for stg
```

---

## 8. BOOTSTRAP SCRIPTS TO CREATE

After Terraform, these scripts need to be created and run:

### 8.1 Script: bootstrap-secrets.sh
Creates all manual secrets in GCP Secret Manager.

### 8.2 Script: bootstrap-eso.sh
Installs ESO and ClusterSecretStore in a cluster.

### 8.3 Script: bootstrap-argocd.sh
Installs ArgoCD and configures repository credentials.

### 8.4 Script: bootstrap-arc.sh
Installs ARC controller and runner scale sets.

### 8.5 Script: create-argocd-applications.sh
Creates ArgoCD Applications for each environment.

---

## 9. VERIFICATION CHECKLIST

After rebuild, verify:

- [ ] VPN connectivity works
- [ ] All clusters accessible via internal IPs
- [ ] ESO installed and ClusterSecretStore ready in all clusters
- [ ] ArgoCD installed in workloads clusters
- [ ] ARC installed in runners cluster
- [ ] Runners appear in GitHub (gameplatform-light, gameplatform-heavy)
- [ ] Artifact Registry repositories exist with correct names
- [ ] Secrets exist in GCP Secret Manager
- [ ] ExternalSecrets syncing correctly
- [ ] Build workflow can push images
- [ ] ArgoCD can deploy applications

---

## 10. REPOSITORY STATUS (Pending Corrections)

### platform-kubernetes-infrastructure
- [ ] Fix all registry references
- [ ] Create bootstrap scripts
- [ ] Update README

### gameplatform-shared-infrastructure-gcp
- [ ] Fix artifact registry naming in 06-workloads
- [ ] Review all terragrunt.hcl files
- [ ] Update documentation

### gameplatform-monorepo
- [ ] Fix workflow registry references
- [ ] Verify environment-variables structure

### gameplatform-shared-actions
- [ ] Review and fix any GCP-related actions

---

*Document created: 2025-12-10*
*Last updated: 2025-12-10*
