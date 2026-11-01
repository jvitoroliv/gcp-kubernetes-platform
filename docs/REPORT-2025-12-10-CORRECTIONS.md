# GamePlatform GCP Infrastructure - Correction Report

**Date**: 2025-12-10
**Status**: All corrections completed

---

## Executive Summary

This report documents all corrections made to the `platform-kubernetes-infrastructure` repository to fix nomenclature issues and create automation scripts for the GCP/GKE infrastructure deployment.

### Key Architecture Clarification

**ArgoCD runs on `gameplatform-nonprod-runners` cluster and manages `project-dev-workloads` and `project-stg-workloads` clusters REMOTELY via ArgoCD Applications.**

```
┌─────────────────────────────────────────────────────────────┐
│              gameplatform-nonprod-runners cluster                  │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────────────────────┐  │
│  │  ARC Controller │  │  ArgoCD (manages dev + stg)     │  │
│  │  ARC Runners    │  │  - game-platform-dev app      │  │
│  │  ESO            │  │  - game-platform-stg app      │  │
│  └─────────────────┘  └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
           │                        │
           │                        ├──────────────────────────┐
           ▼                        ▼                          ▼
┌──────────────────────┐  ┌──────────────────────┐  ┌────────────────┐
│ project-dev-workloads │  │ project-stg-workloads │  │ (future prd)   │
│ - gameplatform-dev ns      │  │ - gameplatform-stg ns      │  │                │
│ - ESO                │  │ - ESO                │  │                │
│ - 8 services         │  │ - 8 services         │  │                │
└──────────────────────┘  └──────────────────────┘  └────────────────┘
```

---

## Corrections Made

### 1. External Secret for ARC GitHub PAT

**File**: `charts/runners/external-secret.yaml`

**Issue**: Referenced wrong secret name `project-dev-github-arc-pat` (environment-specific)

**Fix**: Changed to `gameplatform-nonprod-github-arc-pat` (shared resource for nonprod)

```yaml
# Before
remoteRef:
  key: project-dev-github-arc-pat

# After
remoteRef:
  key: gameplatform-nonprod-github-arc-pat
```

### 2. ArgoCD Application for DEV

**File**: `argocd/dev/application-dev.yaml`

**Issue**: Missing `values-dev.yaml` in helm valueFiles

**Fix**: Added environment-specific values file

```yaml
# Before
helm:
  valueFiles:
    - values.yaml

# After
helm:
  valueFiles:
    - values.yaml
    - values-dev.yaml
```

### 3. README.md - Runners Cluster Section

**File**: `README.md`

**Issues**:
- Wrong cluster name: `project-dev-runners` → `gameplatform-nonprod-runners`
- Wrong region: `southamerica-east1` → `us-east1`
- Missing `--internal-ip` flag (cluster is private)
- Missing ArgoCD in components list

**Fix**: Complete rewrite of runners cluster section with correct values

### 4. External Secrets README

**File**: `charts/external-secrets/README.md`

**Issues**:
- Wrong cluster names
- Wrong region
- Wrong project name (`project-dev-env` → `project-nonprod-env`)
- Missing `--internal-ip` flag
- Wrong secret name reference

**Fix**: Updated all commands with correct cluster names, region, project, and VPN requirement

### 5. ARC Runners README

**File**: `charts/runners/README.md`

**Issues**:
- Architecture diagram with wrong cluster name
- Wrong secret name (`project-dev-github-arc-pat`)
- Wrong cluster connection commands
- Wrong project in all gcloud commands

**Fix**: Complete update of all references to use correct nomenclature

### 6. Secrets Setup Documentation

**File**: `docs/secrets-setup.md`

**Issues**:
- Wrong project name (`project-dev-env` instead of `project-nonprod-env`)
- Wrong service account names

**Fix**: Updated all project references and added clarification comments

### 7. Runner Image README

**File**: `images/runner/README.md`

**Issues**:
- Wrong cluster name and region
- Wrong artifact registry path
- Wrong pod label selector

**Fix**: Updated with correct cluster connection and registry paths

---

## Scripts Created

### 1. `scripts/bootstrap/01-create-secrets.sh`

**Purpose**: Interactive script to create all required secrets in GCP Secret Manager

**Features**:
- Creates ~30 secrets per environment
- Interactive prompts for secret values
- Supports dev, stg, prd environments
- Uses `printf` to avoid trailing newlines

**Usage**:
```bash
./01-create-secrets.sh dev
./01-create-secrets.sh stg
```

### 2. `scripts/bootstrap/02-bootstrap-runners.sh`

**Purpose**: Bootstrap the runners cluster with ESO, ARC, and ArgoCD

**Installs**:
- External Secrets Operator (ESO)
- ClusterSecretStore for GCP Secret Manager
- ARC Controller (arc-systems namespace)
- ARC Light Runners (arc-runners namespace)
- ARC Heavy Runners (arc-runners namespace)
- ArgoCD (argocd namespace)

**Usage**:
```bash
# Connect to runners cluster via VPN
gcloud container clusters get-credentials gameplatform-nonprod-runners \
  --region us-east1 --project project-nonprod-env --internal-ip

./02-bootstrap-runners.sh
```

### 3. `scripts/bootstrap/03-bootstrap-workloads.sh`

**Purpose**: Bootstrap workloads clusters (dev/stg) with ESO

**Installs**:
- External Secrets Operator (ESO)
- ClusterSecretStore for GCP Secret Manager
- Application namespace (gameplatform-dev or gameplatform-stg)
- ArgoCD manager ServiceAccount for remote access

**Usage**:
```bash
# Connect to dev workloads cluster via VPN
gcloud container clusters get-credentials project-dev-workloads \
  --region us-east1 --project project-nonprod-env --internal-ip

./03-bootstrap-workloads.sh dev
```

### 4. `scripts/bootstrap/04-configure-argocd.sh`

**Purpose**: Configure ArgoCD on runners cluster to manage dev and stg

**Configures**:
- Repository credentials (GitHub PAT)
- Remote cluster registration (dev-workloads, stg-workloads)
- ArgoCD Applications for each environment

**Usage**:
```bash
# Connect to runners cluster via VPN
gcloud container clusters get-credentials gameplatform-nonprod-runners \
  --region us-east1 --project project-nonprod-env --internal-ip

./04-configure-argocd.sh
```

---

## Documents Created

### EXECUTION-PATH.md

**Location**: `/docs/GamePlatform/EXECUTION-PATH.md`

**Purpose**: Complete step-by-step guide to deploy infrastructure from scratch

**Contents**:
- Phase 0: Prerequisites
- Phase 1: Terraform Infrastructure (all stacks in order)
- Phase 2: VPN Setup
- Phase 3: Create Secrets
- Phase 4: Bootstrap Runners Cluster
- Phase 5: Bootstrap Workloads Clusters
- Phase 6: Configure ArgoCD
- Phase 7: Build and Deploy Applications
- Phase 8: Verification Checklist
- Quick Reference Commands
- Destruction Order

---

## Nomenclature Reference

### Correct Names

| Resource | Correct Name | Wrong Names (Fixed) |
|----------|--------------|---------------------|
| Nonprod Project | `project-nonprod-env` | `project-dev-env` |
| Runners Cluster | `gameplatform-nonprod-runners` | `project-dev-runners` |
| Dev Cluster | `project-dev-workloads` | `project-dev-gke` |
| Stg Cluster | `project-stg-workloads` | - |
| Region (nonprod) | `us-east1` | `southamerica-east1` |
| GitHub PAT Secret | `gameplatform-nonprod-github-arc-pat` | `project-dev-github-arc-pat` |
| Artifact Registry | `project-dev-gameplatform` | `gameplatform-nonprod-gameplatform` |

### Environment Prefixes

| Environment | Secret Prefix | Namespace |
|-------------|---------------|-----------|
| Development | `project-dev-*` | `gameplatform-dev` |
| Staging | `project-stg-*` | `gameplatform-stg` |
| Production | `project-prd-*` | `gameplatform-prd` |

---

## Files Modified Summary

```
platform-kubernetes-infrastructure/
├── charts/
│   ├── external-secrets/
│   │   └── README.md                    # Updated cluster/project names
│   └── runners/
│       ├── external-secret.yaml         # Fixed secret name
│       └── README.md                    # Updated cluster/project names
├── argocd/
│   └── dev/
│       └── application-dev.yaml         # Added values-dev.yaml
├── docs/
│   └── secrets-setup.md                 # Updated project names
├── images/
│   └── runner/
│       └── README.md                    # Updated cluster/registry paths
├── scripts/
│   └── bootstrap/
│       ├── 01-create-secrets.sh         # NEW - Create GCP secrets
│       ├── 02-bootstrap-runners.sh      # NEW - Bootstrap runners cluster
│       ├── 03-bootstrap-workloads.sh    # NEW - Bootstrap workloads clusters
│       └── 04-configure-argocd.sh       # NEW - Configure ArgoCD
└── README.md                            # Updated runners section
```

---

## Next Steps

1. **Commit all changes** to `platform-kubernetes-infrastructure` repository
2. **Re-apply Terraform** stacks in order (see EXECUTION-PATH.md)
3. **Connect to VPN** (WireGuard via bastion host)
4. **Run bootstrap scripts** in order:
   - `01-create-secrets.sh dev` (if secrets don't exist)
   - `02-bootstrap-runners.sh`
   - `03-bootstrap-workloads.sh dev`
   - `03-bootstrap-workloads.sh stg`
   - `04-configure-argocd.sh`
5. **Build images** via GitHub Actions workflow
6. **Verify deployment** via ArgoCD UI

---

*Report generated: 2025-12-10*
