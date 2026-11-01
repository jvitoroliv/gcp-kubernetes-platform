# GCP Kubernetes Bootstrap Analysis

**Date**: 2025-12-10
**Purpose**: Document what was installed manually in clusters and design automated bootstrap solution

---

## 1. CURRENT STATE ANALYSIS

### What Already Exists (Scripts & Configs)

The repository `platform-kubernetes-infrastructure` already has a good foundation:

#### Scripts (charts/ directory)
| Script | Purpose | Status |
|--------|---------|--------|
| `charts/external-secrets/install.sh` | Install ESO with Helm | ✅ Good |
| `charts/runners/install.sh` | Install ARC (controller + runners) | ✅ Good |
| `scripts/install-argocd.sh` | Install ArgoCD | ⚠️ Needs update |
| `scripts/install-external-secrets.sh` | Install ESO (alternative) | ⚠️ Duplicate/outdated |
| `scripts/deploy.sh` | Deploy Helm charts | Needs review |
| `scripts/install-cert-manager.sh` | Install cert-manager | Needs review |

#### GitHub Actions Workflow
| Workflow | Purpose | Status |
|----------|---------|--------|
| `bootstrap-cluster.yml` | Install ESO + ArgoCD via CI/CD | ✅ Good structure |
| `build-runner-image.yml` | Build custom runner image | Needs PAT secret |

#### Configuration Files
| File | Purpose | Status |
|------|---------|--------|
| `charts/external-secrets/values.yaml` | ESO base config | ✅ OK |
| `charts/external-secrets/values-workloads.yaml` | ESO for workloads cluster | ⚠️ Wrong project ref |
| `charts/external-secrets/values-runners.yaml` | ESO for runners cluster | ⚠️ Wrong project ref |
| `charts/external-secrets/cluster-secret-store.yaml` | ClusterSecretStore | ✅ OK |
| `charts/runners/external-secret.yaml` | ExternalSecret for ARC PAT | ✅ OK |
| `charts/runners/controller/values.yaml` | ARC controller config | ✅ OK |
| `charts/runners/runner-light/values.yaml` | Light runner config | ⚠️ Wrong image registry |
| `charts/runners/runner-heavy/values.yaml` | Heavy runner config | ⚠️ Wrong image registry |

---

## 2. PROBLEMS IDENTIFIED

### 2.1 Hardcoded Wrong Project IDs

**File**: `charts/external-secrets/values-workloads.yaml`
```yaml
# WRONG:
iam.gke.io/gcp-service-account: project-dev-eso-workloads@project-dev-env.iam.gserviceaccount.com
# SHOULD BE:
iam.gke.io/gcp-service-account: project-dev-eso-workloads@project-nonprod-env.iam.gserviceaccount.com
```

**File**: `charts/external-secrets/values-runners.yaml`
```yaml
# WRONG:
iam.gke.io/gcp-service-account: project-dev-eso-runners@project-dev-env.iam.gserviceaccount.com
# SHOULD BE:
iam.gke.io/gcp-service-account: gameplatform-nonprod-eso-runners@project-nonprod-env.iam.gserviceaccount.com
```

### 2.2 Wrong Registry References

**File**: `charts/runners/runner-heavy/values.yaml`
```yaml
# WRONG:
image: us-east1-docker.pkg.dev/project-nonprod-env/project-dev-images/gameplatform-runner:latest
# SHOULD BE (after fix):
image: us-east1-docker.pkg.dev/project-nonprod-env/gameplatform-nonprod-images/gameplatform-runner:latest
```

### 2.3 Missing Components for Full Automation

What was done manually but NOT in scripts:

1. **ArgoCD Application creation** - No script to create Applications
2. **ArgoCD repository credentials** - No script to configure GitHub repo access
3. **Namespace creation** - Only partial (gameplatform-dev, gameplatform-stg)
4. **GCP Secrets creation** - No script to create initial secrets
5. **ConfigMaps sync** - Exists as workflow but not as script

### 2.4 Bootstrap Workflow Limitations

The `bootstrap-cluster.yml` workflow:
- ✅ Installs ESO
- ✅ Installs ArgoCD
- ❌ Does NOT install ARC (separate process)
- ❌ Does NOT create ArgoCD Applications
- ❌ Does NOT configure ArgoCD repo credentials
- ❌ Does NOT create workload namespaces
- ❌ Cannot run if runners don't exist (chicken-egg problem)

---

## 3. WHAT WAS INSTALLED MANUALLY (Historical Reference)

### 3.1 Runners Cluster (`gameplatform-nonprod-runners`)

Commands that were run manually:

```bash
# 1. Connect to cluster
gcloud container clusters get-credentials gameplatform-nonprod-runners \
  --region us-east1 --project project-nonprod-env --internal-ip

# 2. Install ESO (from install.sh)
cd charts/external-secrets
./install.sh runners

# 3. Fix node taint (had to be done manually due to GKE issue)
gcloud container node-pools update gameplatform-nonprod-arc-controller \
  --cluster gameplatform-nonprod-runners \
  --region us-east1 \
  --project project-nonprod-env \
  --node-taints="components.gke.io/gke-managed-components=true:NoSchedule"

# 4. Create GitHub PAT secret in GCP Secret Manager
printf '%s' "github_pat_xxxx" | gcloud secrets versions add github-arc-pat \
  --data-file=- --project=project-nonprod-env

# 5. Install ARC (from install.sh)
cd charts/runners
./install.sh

# 6. Fix ESO webhook validation (had to delete webhooks)
kubectl delete validatingwebhookconfigurations secretstore-validate
kubectl delete validatingwebhookconfigurations externalsecret-validate
```

### 3.2 Dev Workloads Cluster (`project-dev-workloads`)

```bash
# 1. Connect to cluster
gcloud container clusters get-credentials project-dev-workloads \
  --region us-east1 --project project-nonprod-env --internal-ip

# 2. Install ESO
cd charts/external-secrets
./install.sh workloads

# 3. Create namespace
kubectl create namespace gameplatform-dev

# 4. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 5. Configure ArgoCD repo credentials (MANUALLY)
kubectl create secret generic argocd-repo-creds \
    -n argocd \
    --from-literal=url=https://github.com/example-gamedev-org/platform-kubernetes-infrastructure.git \
    --from-literal=username=devops-engineer-gameplatform \
    --from-literal=password=github_pat_xxxxx

# 6. Add master authorized networks for runners
gcloud container clusters update project-dev-workloads \
  --region us-east1 \
  --project project-nonprod-env \
  --enable-master-authorized-networks \
  --master-authorized-networks "10.124.0.0/14"

# 7. Create ArgoCD Application (MANUALLY via kubectl apply)
# This was done inline, no file exists
```

### 3.3 GCP Secret Manager (Manual)

These secrets were created manually via gcloud:

```bash
# Database secrets (created by Terraform 04-database)
# - project-dev-db-host
# - project-dev-db-nakama-connection
# - project-dev-db-nakama-password
# - project-dev-db-lobby-connection
# - project-dev-db-lobby-password

# Application secrets (created manually)
gcloud secrets create project-dev-nakama-http-key --project=project-nonprod-env
gcloud secrets create project-dev-nakama-server-key --project=project-nonprod-env
gcloud secrets create project-dev-aes-encryption-key --project=project-nonprod-env
gcloud secrets create project-dev-nextauth-secret --project=project-nonprod-env
gcloud secrets create project-dev-google-client-id --project=project-nonprod-env
gcloud secrets create project-dev-google-client-secret --project=project-nonprod-env
gcloud secrets create project-dev-aes-api-key --project=project-nonprod-env
gcloud secrets create project-dev-smtp-user --project=project-nonprod-env
gcloud secrets create project-dev-smtp-password --project=project-nonprod-env
gcloud secrets create project-dev-ai-api-key --project=project-nonprod-env
gcloud secrets create project-dev-ais-app-secret --project=project-nonprod-env
gcloud secrets create project-dev-piapi-key --project=project-nonprod-env
gcloud secrets create project-dev-gemini-api-key --project=project-nonprod-env
gcloud secrets create project-dev-yuno-public-key --project=project-nonprod-env
gcloud secrets create project-dev-yuno-private-key --project=project-nonprod-env
gcloud secrets create project-dev-yuno-account-id --project=project-nonprod-env
gcloud secrets create github-arc-pat --project=project-nonprod-env
```

---

## 4. PROPOSED BOOTSTRAP ARCHITECTURE

### 4.1 Bootstrap Order (Dependency Chain)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BOOTSTRAP ORDER                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PHASE 1: INFRASTRUCTURE (Terraform)                                         │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 01-foundation → 02-networking → 03-gke → 04-database →               │   │
│  │ 05-dns-lb → 06-workloads → 07-vpn-bastion → 08-gke-runners          │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│  PHASE 2: SECRETS SETUP (Script - runs once per environment)                 │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ create-secrets.sh dev                                                 │   │
│  │ - Creates all application secrets in GCP Secret Manager              │   │
│  │ - Prompts for values or reads from secure file                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│  PHASE 3: RUNNERS CLUSTER BOOTSTRAP (Script - runs once)                     │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ bootstrap-runners.sh                                                  │   │
│  │ 1. Connect to runners cluster                                         │   │
│  │ 2. Install ESO (charts/external-secrets/install.sh runners)          │   │
│  │ 3. Wait for ESO ready                                                 │   │
│  │ 4. Install ARC (charts/runners/install.sh)                           │   │
│  │ 5. Verify runners appear in GitHub                                    │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│  PHASE 4: WORKLOADS CLUSTER BOOTSTRAP (CI/CD - after runners exist)          │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ GitHub Actions: bootstrap-cluster.yml (runs-on: gameplatform-heavy)        │   │
│  │ 1. Connect to workloads cluster                                       │   │
│  │ 2. Install ESO                                                        │   │
│  │ 3. Install ArgoCD                                                     │   │
│  │ 4. Create workload namespace (gameplatform-dev)                            │   │
│  │ 5. Configure ArgoCD repo credentials                                  │   │
│  │ 6. Create ArgoCD Application                                          │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│  PHASE 5: APPLICATION DEPLOYMENT (CI/CD - automatic via ArgoCD)              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ Build images → Push to Artifact Registry → ArgoCD syncs              │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Script Structure Proposal

```
platform-kubernetes-infrastructure/
├── scripts/
│   ├── bootstrap/
│   │   ├── 00-verify-prerequisites.sh    # Check gcloud, kubectl, helm, VPN
│   │   ├── 01-create-secrets.sh          # Create GCP secrets (interactive)
│   │   ├── 02-bootstrap-runners.sh       # ESO + ARC on runners cluster
│   │   ├── 03-bootstrap-workloads.sh     # ESO + ArgoCD + namespace
│   │   ├── 04-configure-argocd.sh        # Repo creds + Applications
│   │   └── full-bootstrap.sh             # Run all in sequence
│   └── utils/
│       ├── connect-cluster.sh            # Helper to connect to cluster
│       └── verify-installation.sh        # Verify all components
├── charts/
│   ├── external-secrets/
│   │   ├── install.sh                    # (existing - keep)
│   │   └── ...
│   └── runners/
│       ├── install.sh                    # (existing - keep)
│       └── ...
└── argocd/                               # NEW DIRECTORY
    ├── applications/
    │   ├── dev-platform.yaml             # ArgoCD App for dev
    │   ├── stg-platform.yaml             # ArgoCD App for stg
    │   └── prd-platform.yaml             # ArgoCD App for prd
    └── repo-credentials/
        └── template.yaml                 # Template (no real creds)
```

### 4.3 Workflow Updates

Update `bootstrap-cluster.yml` to:
1. Support ARC installation (for runners cluster only)
2. Create ArgoCD Applications
3. Configure ArgoCD repo credentials (using GitHub secret)

Add new workflows:
1. `bootstrap-secrets.yml` - Create secrets from GitHub secrets/vars
2. `sync-configmaps.yml` - Already exists, verify working

---

## 5. CHICKEN-EGG PROBLEM: RUNNERS

### Problem
- To run GitHub Actions on private cluster, need self-hosted runners
- To install self-hosted runners, need to run commands on private cluster
- First bootstrap MUST be done manually (or via VPN)

### Solution
**Phase 2 (runners bootstrap) must be run manually the FIRST time**:

```bash
# ONE-TIME MANUAL SETUP (requires VPN connection)
# After this, all other operations can be automated via CI/CD

# 1. Connect to VPN
# 2. Run runners bootstrap script
./scripts/bootstrap/02-bootstrap-runners.sh

# 3. Verify runners appear in GitHub
# 4. Now CI/CD can use runners for everything else
```

After runners exist, the `bootstrap-cluster.yml` workflow can bootstrap other clusters automatically.

---

## 6. CONFIGURATION ISSUES TO FIX

### 6.1 Files with Wrong Project IDs

| File | Current | Correct |
|------|---------|---------|
| `charts/external-secrets/values-workloads.yaml` | `project-dev-env` | `project-nonprod-env` |
| `charts/external-secrets/values-runners.yaml` | `project-dev-env` | `project-nonprod-env` |
| `scripts/install-external-secrets.sh` | `project-dev-env` | `project-nonprod-env` |

### 6.2 Files with Wrong Registry

| File | Current | Correct |
|------|---------|---------|
| `charts/runners/runner-heavy/values.yaml` | `project-dev-images` | `gameplatform-nonprod-images` |

### 6.3 Missing ArgoCD Application Files

Need to create:
- `argocd/applications/dev-platform.yaml`
- `argocd/applications/stg-platform.yaml`
- `argocd/applications/prd-platform.yaml`

### 6.4 Missing Bootstrap Scripts

Need to create:
- `scripts/bootstrap/01-create-secrets.sh`
- `scripts/bootstrap/02-bootstrap-runners.sh`
- `scripts/bootstrap/03-bootstrap-workloads.sh`
- `scripts/bootstrap/04-configure-argocd.sh`

---

## 7. RECOMMENDED NEXT STEPS

### Immediate (Before Destroy)
1. [ ] Save current secrets values from GCP Secret Manager
2. [ ] Export ArgoCD Application configuration
3. [ ] Document any manual configs not captured

### After Terraform Fixes
1. [ ] Fix ESO values files (project IDs)
2. [ ] Fix runner values files (registry names)
3. [ ] Create bootstrap scripts
4. [ ] Create ArgoCD Application manifests
5. [ ] Update bootstrap-cluster.yml workflow

### Rebuild Process
1. Run Terraform to create infrastructure
2. Connect via VPN
3. Run `02-bootstrap-runners.sh` manually
4. Verify runners in GitHub
5. Run `bootstrap-cluster.yml` workflow for workloads clusters
6. Verify ArgoCD + ESO working
7. Build and push images
8. Verify deployment via ArgoCD

---

*Document created: 2025-12-10*
