# GitHub Actions Runner Controller (ARC)

Self-hosted GitHub Actions runners running on GKE.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│           gameplatform-nonprod-runners GKE Cluster                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  controller-pool (e2-small, min=1)                   │   │
│  │  Taint: components.gke.io/gke-managed-components     │   │
│  │  ┌─────────────────────────────────────────────┐    │   │
│  │  │  ARC Controller + ESO                        │    │   │
│  │  │  - Receives GitHub webhooks                  │    │   │
│  │  │  - Manages runner lifecycle                  │    │   │
│  │  │  - Always running                            │    │   │
│  │  └─────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  runners-light (e2-standard-2, Spot, min=0)          │   │
│  │  ┌─────────────────────────────────────────────┐    │   │
│  │  │  gameplatform-light runners                        │    │   │
│  │  │  - Lint, tests, simple jobs                  │    │   │
│  │  │  - Scale 0-5 based on demand                 │    │   │
│  │  └─────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  runners-heavy (e2-standard-8, Spot, min=0)          │   │
│  │  ┌─────────────────────────────────────────────┐    │   │
│  │  │  gameplatform-heavy runners                        │    │   │
│  │  │  - Docker builds (DinD)                      │    │   │
│  │  │  - Scale 0-5 based on demand                 │    │   │
│  │  └─────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **GKE Runners Cluster** deployed via `08-gke-runners` stack
2. **06-workloads stack applied** with `enable_external_secrets = true`
3. **GitHub PAT stored in GCP Secret Manager** (`gameplatform-nonprod-github-arc-pat`)
4. **External Secrets Operator installed** on runners cluster
5. **kubectl** configured to connect to the runners cluster
6. **Helm v3+** installed

### GitHub PAT Requirements

The PAT must have the following permissions:
- For **organization runners**: `admin:org` scope
- For **repository runners**: `repo` scope

### Connect to Cluster

```bash
# Via VPN (cluster is private)
gcloud container clusters get-credentials gameplatform-nonprod-runners \
  --region us-east1 \
  --project project-nonprod-env \
  --internal-ip
```

### Store GitHub PAT in GCP Secret Manager

⚠️ **IMPORTANT**: Always use `printf '%s'` instead of `echo` to avoid trailing newlines that cause authentication errors.

```bash
# Add or update the PAT value (CORRECT - no trailing newline)
printf '%s' "ghp_your_pat_here" | gcloud secrets versions add gameplatform-nonprod-github-arc-pat \
  --data-file=- \
  --project=project-nonprod-env

# WRONG - echo adds a newline which breaks HTTP Authorization header
# echo "ghp_your_pat_here" | gcloud secrets versions add ...
```

## Installation

### Step 1: Install External Secrets Operator

```bash
cd charts/external-secrets
./install.sh runners
```

### Step 2: Install ARC (uses ExternalSecret automatically)

```bash
cd charts/runners
./install.sh
```

### Legacy: Manual Secret (not recommended)

```bash
./install.sh --manual <your-github-pat>
```

### Manual Install

```bash
# 1. Create namespaces
kubectl create namespace arc-systems
kubectl create namespace arc-runners

# 2. Apply ExternalSecret (if ESO is installed)
kubectl apply -f external-secret.yaml

# 3. Install ARC controller
helm upgrade --install arc \
  --namespace arc-systems \
  --values controller/values.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

# 4. Install light runners
helm upgrade --install arc-runner-light \
  --namespace arc-runners \
  --values runner-light/values.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

# 5. Install heavy runners
helm upgrade --install arc-runner-heavy \
  --namespace arc-runners \
  --values runner-heavy/values.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

## Usage in Workflows

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint:
    runs-on: gameplatform-light  # Light runner (2 vCPU, 8GB)
    steps:
      - uses: actions/checkout@v4
      - run: npm run lint

  test:
    runs-on: gameplatform-light
    steps:
      - uses: actions/checkout@v4
      - run: npm test

  build:
    runs-on: gameplatform-heavy  # Heavy runner (8 vCPU, 32GB, Docker)
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t myapp .
      - run: docker push gcr.io/project-dev-env/myapp
```

## Runner Specifications

| Runner | Machine Type | CPU | Memory | Disk | Docker | Use Case |
|--------|--------------|-----|--------|------|--------|----------|
| `gameplatform-light` | e2-standard-2 | 2 vCPU | 8 GB | 50 GB | No | Lint, tests, scripts |
| `gameplatform-heavy` | e2-standard-8 | 8 vCPU | 32 GB | 100 GB | Yes (DinD) | Docker builds |

## Node Pool Taints

| Pool | Taint | Purpose |
|------|-------|---------|
| arc-controller | `components.gke.io/gke-managed-components=true:NoSchedule` | Controller, listeners, system pods |
| runners-light | `runner-type=light:NoSchedule` | Light runner pods only |
| runners-heavy | `runner-type=heavy:NoSchedule` | Heavy runner pods only |

## Scaling

- **Min runners**: 0 (scale to zero when idle)
- **Max runners**: 5 per type
- **Scale up**: ~30-60 seconds (node provisioning + pod scheduling)
- **Scale down**: After job completion

## Monitoring

```bash
# Check controller
kubectl get pods -n arc-systems

# Check runners
kubectl get pods -n arc-runners

# Check runner scale sets
kubectl get autoscalingrunnersets -n arc-runners

# Check nodes
kubectl get nodes -l runner_type=light
kubectl get nodes -l runner_type=heavy

# View logs
kubectl logs -n arc-systems -l app.kubernetes.io/name=gha-rs-controller

# Check ExternalSecret status
kubectl get externalsecret -n arc-runners
kubectl describe externalsecret arc-github-secret -n arc-runners
```

## Force Secret Resync

If you update the PAT in GCP Secret Manager:

```bash
# 1. Update the PAT (use printf to avoid newline!)
printf '%s' "ghp_new_token" | gcloud secrets versions add gameplatform-nonprod-github-arc-pat \
  --data-file=- --project=project-nonprod-env

# 2. Force ESO to resync the secret
kubectl annotate externalsecret arc-github-secret -n arc-runners \
  force-sync=$(date +%s) --overwrite

# 3. Verify the secret was updated
kubectl get externalsecret arc-github-secret -n arc-runners
```

## Uninstall

```bash
./install.sh --uninstall

# Or manually:
helm uninstall arc-runner-heavy -n arc-runners
helm uninstall arc-runner-light -n arc-runners
helm uninstall arc -n arc-systems
kubectl delete namespace arc-runners arc-systems
```

## Troubleshooting

### PAT Permission Error

If you see `"Resource not accessible by personal access token"` in controller logs:

1. **Verify PAT permissions** at https://github.com/settings/tokens:
   - For **organization runners**: "Self-hosted runners: Read and Write" in Organization permissions
   - For **repository runners**: `repo` scope
2. **Update PAT in GCP Secret Manager** (use printf to avoid newline!):
   ```bash
   printf '%s' "ghp_new_token" | gcloud secrets versions add gameplatform-nonprod-github-arc-pat \
     --data-file=- --project=project-nonprod-env
   ```
3. **Force ExternalSecret resync**:
   ```bash
   kubectl annotate externalsecret arc-github-secret -n arc-runners \
     force-sync=$(date +%s) --overwrite
   ```
4. **Restart ARC controller** to pick up new credentials:
   ```bash
   kubectl rollout restart deployment/arc-gha-rs-controller -n arc-systems
   ```

### Runners not scaling up

1. Check controller logs:
   ```bash
   kubectl logs -n arc-systems -l app.kubernetes.io/name=gha-rs-controller
   ```

2. Check if nodes are available:
   ```bash
   kubectl get nodes
   kubectl describe nodes
   ```

3. Verify GitHub secret:
   ```bash
   kubectl get secret arc-github-secret -n arc-runners
   kubectl get externalsecret arc-github-secret -n arc-runners
   ```

### Runners stuck in Pending

1. Check node pool autoscaling:
   ```bash
   kubectl describe pod <pod-name> -n arc-runners
   ```

2. Check if taints/tolerations match:
   ```bash
   kubectl get nodes -o jsonpath='{.items[*].spec.taints}'
   ```

### Docker not working in heavy runners

1. Check DinD sidecar:
   ```bash
   kubectl logs <pod-name> -n arc-runners -c dind
   ```

2. Verify privileged mode:
   ```bash
   kubectl get pod <pod-name> -n arc-runners -o yaml | grep privileged
   ```

### ESO Secret Not Syncing

1. Check ClusterSecretStore:
   ```bash
   kubectl get clustersecretstore gcp-secret-manager
   kubectl describe clustersecretstore gcp-secret-manager
   ```

2. Check ESO controller logs:
   ```bash
   kubectl logs -n external-secrets deployment/external-secrets
   ```

3. Verify Workload Identity:
   ```bash
   kubectl get sa external-secrets -n external-secrets -o yaml
   ```

## Files

```
charts/runners/
├── README.md                 # This file
├── install.sh                # Installation script
├── external-secret.yaml      # ExternalSecret for GitHub PAT
├── controller/
│   └── values.yaml           # ARC controller configuration
├── runner-light/
│   └── values.yaml           # Light runners configuration
└── runner-heavy/
    └── values.yaml           # Heavy runners configuration
```

## References

- [ARC Documentation](https://github.com/actions/actions-runner-controller)
- [ARC Helm Charts](https://github.com/actions/actions-runner-controller/tree/master/charts)
- [GitHub Actions Self-hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [External Secrets Operator](https://external-secrets.io/)
- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
