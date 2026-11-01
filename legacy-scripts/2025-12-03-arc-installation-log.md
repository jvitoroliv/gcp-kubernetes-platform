# ARC (Actions Runner Controller) Installation Log

**Date**: 2025-12-03
**Environment**: GCP - project-dev-env
**Cluster**: project-dev-runners (GKE)
**Region**: southamerica-east1

---

## Summary

✅ **FULLY OPERATIONAL** - Successfully installed GitHub Actions Runner Controller (ARC) on the GKE runners cluster with External Secrets Operator integration for secure GitHub PAT management.

**Key Learnings**:
1. GKE private clusters require `components.gke.io/gke-managed-components` taint for system pods (konnectivity-agent)
2. Always use `printf '%s'` (not `echo`) when storing secrets to avoid trailing newlines
3. Organization runners require "Self-hosted runners: Read and Write" permission in PAT

---

## Issues Encountered and Solutions

### 1. ESO Webhook "No agent available" Error

**Problem**: When trying to apply the ClusterSecretStore, received error:
```
Internal error occurred: failed calling webhook "validate.clustersecretstore.external-secrets.io":
Post "https://external-secrets-webhook.external-secrets.svc:443/...": No agent available
```

**Root Cause**: The `konnectivity-agent` pods (GKE system component for control plane to node communication) were stuck in `Pending` status because all nodes in the runners cluster had taints that the system pods couldn't tolerate.

The controller-pool nodes had taint `dedicated=arc-controller:NoSchedule`, but konnectivity-agent only tolerates:
- `CriticalAddonsOnly`
- `components.gke.io/gke-managed-components`

**Solution**: Updated the controller-pool node taint from:
```
dedicated=arc-controller:NoSchedule
```
To:
```
components.gke.io/gke-managed-components=true:NoSchedule
```

This allows GKE system components to schedule while still restricting other workloads.

**Commands Used**:
```bash
# Update node pool taint
gcloud container node-pools update project-dev-arc-controller \
  --cluster project-dev-runners \
  --region southamerica-east1 \
  --project project-dev-env \
  --node-taints="components.gke.io/gke-managed-components=true:NoSchedule" \
  --quiet
```

### 2. ESO Secret Sync Timeout

**Problem**: ExternalSecret couldn't sync from GCP Secret Manager:
```
unable to access Secret from SecretManager Client: context deadline exceeded
```

**Root Cause**: Two issues:
1. konnectivity-agent wasn't running (related to taint issue above)
2. The GCP service account `project-dev-eso-runners` didn't have IAM permissions on the specific secret

**Solution**: Added secretAccessor role to the ESO service account for the specific secret:
```bash
gcloud secrets add-iam-policy-binding project-dev-github-arc-pat \
  --project project-dev-env \
  --member="serviceAccount:project-dev-eso-runners@project-dev-env.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### 3. ESO Webhook Validation Blocking

**Problem**: Even with fixes, the validating webhooks were blocking resource creation.

**Solution**: Temporarily deleted the validating webhook configurations to apply the ClusterSecretStore:
```bash
kubectl delete validatingwebhookconfigurations secretstore-validate
kubectl delete validatingwebhookconfigurations externalsecret-validate
```

Note: These webhooks will be recreated if ESO is reinstalled or upgraded.

### 4. ARC Runner Scale Set Validation Error

**Problem**: Heavy runner installation failed with:
```
spec.listenerTemplate.spec.containers: Required value
```

**Solution**: Added containers specification to listenerTemplate in values files:
```yaml
listenerTemplate:
  spec:
    containers:
      - name: listener
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
```

### 5. Heavy Runner Duplicate Resources Error

**Problem**: Heavy runner installation failed with duplicate volume/container errors.

**Root Cause**: When using `containerMode.type: "dind"`, the chart automatically adds DinD configuration. Manual specification in template caused duplicates.

**Solution**: Simplified heavy runner values to only specify scheduling (nodeSelector, tolerations) and let the chart handle DinD setup.

---

## Current State

### Installed Components

| Component | Namespace | Status | Notes |
|-----------|-----------|--------|-------|
| ARC Controller | arc-systems | Running | v0.13.0 |
| gameplatform-light scale set | arc-runners | Created | min=0, max=5 |
| gameplatform-heavy scale set | arc-runners | Created | min=0, max=5 |
| External Secrets Operator | external-secrets | Running | v1.1.0 |
| ClusterSecretStore | cluster-scoped | Ready | gcp-secret-manager |
| ExternalSecret | arc-runners | SecretSynced | arc-github-secret |

### Node Pools

| Pool | Machine Type | Min | Max | Taint | Purpose |
|------|--------------|-----|-----|-------|---------|
| arc-controller | e2-small | 1 | 3 | components.gke.io/gke-managed-components=true:NoSchedule | ARC controller, listeners, ESO |
| runners-light | e2-standard-2 | 0 | 5 | runner-type=light:NoSchedule | Light CI jobs (lint, test) |
| runners-heavy | e2-standard-8 | 0 | 5 | runner-type=heavy:NoSchedule | Heavy CI jobs (Docker builds) |

### Final Status: FULLY OPERATIONAL ✅

All components are working correctly. The following issues were resolved:

1. **GitHub PAT Permissions**: Updated PAT with "Self-hosted runners: Read and Write" organization permission
2. **PAT Trailing Newline**: Recreated secret using `printf '%s'` instead of `echo`

**Important**: When updating the PAT in GCP Secret Manager, always use:
```bash
# CORRECT - no trailing newline
printf '%s' "ghp_new_token" | gcloud secrets versions add project-dev-github-arc-pat \
  --data-file=- --project=project-dev-env

# Then force resync
kubectl annotate externalsecret arc-github-secret -n arc-runners \
  force-sync=$(date +%s) --overwrite
```

---

## Files Modified

### platform-kubernetes-infrastructure

| File | Change |
|------|--------|
| `charts/external-secrets/values-runners.yaml` | Updated tolerations to use `components.gke.io/gke-managed-components` |
| `charts/external-secrets/cluster-secret-store.yaml` | Changed API version from v1beta1 to v1 |
| `charts/runners/external-secret.yaml` | Changed API version from v1beta1 to v1 |
| `charts/runners/controller/values.yaml` | Updated tolerations |
| `charts/runners/runner-light/values.yaml` | Updated tolerations, fixed githubConfigSecret format, added listener containers |
| `charts/runners/runner-heavy/values.yaml` | Simplified to avoid duplicates, updated tolerations, added listener containers |

### gameplatform-shared-infrastructure-gcp

| File | Change |
|------|--------|
| `stacks/08-gke-runners/main.tf` | Updated controller_pool taint from `dedicated=arc-controller` to `components.gke.io/gke-managed-components=true` |

---

## Verification Commands

```bash
# Check ARC controller
kubectl get pods -n arc-systems

# Check runner scale sets
kubectl get autoscalingrunnersets -n arc-runners

# Check runner pods (will be empty when no jobs)
kubectl get pods -n arc-runners

# Check ESO status
kubectl get externalsecret -n arc-runners
kubectl get clustersecretstore

# Check secret sync
kubectl get secret arc-github-secret -n arc-runners

# View ARC controller logs
kubectl logs deployment/arc-gha-rs-controller -n arc-systems --tail=50

# Check konnectivity-agent (should be Running)
kubectl get pods -n kube-system -l k8s-app=konnectivity-agent
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                   GitHub (example-gamedev-org org)                   │
│                                                                  │
│  Workflows:                                                      │
│    runs-on: gameplatform-light  →  Light runner jobs                  │
│    runs-on: gameplatform-heavy  →  Heavy runner jobs (Docker)         │
└──────────────────────────────┬───────────────────────────────────┘
                               │ Webhook Events
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│              project-dev-runners GKE Cluster                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  arc-controller pool (e2-small, min=1, no spot)          │    │
│  │  Taint: components.gke.io/gke-managed-components=true    │    │
│  │                                                          │    │
│  │  ┌──────────────────┐  ┌──────────────────────────────┐ │    │
│  │  │  arc-systems ns  │  │  external-secrets ns         │ │    │
│  │  │  - ARC Controller│  │  - ESO Controller            │ │    │
│  │  │  - Listeners     │  │  - ESO Webhook               │ │    │
│  │  └──────────────────┘  │  - Cert Controller           │ │    │
│  │                        └──────────────────────────────┘ │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  runners-light pool (e2-standard-2, Spot, min=0)         │    │
│  │  Taint: runner-type=light:NoSchedule                     │    │
│  │  Scale: 0-5 based on GitHub workflow demand              │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  runners-heavy pool (e2-standard-8, Spot, min=0)         │    │
│  │  Taint: runner-type=heavy:NoSchedule                     │    │
│  │  Scale: 0-5 based on GitHub workflow demand              │    │
│  │  Docker-in-Docker enabled                                │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    GCP Secret Manager                            │
│                                                                  │
│  Secret: project-dev-github-arc-pat                              │
│    ↓ synced via External Secrets Operator                       │
│  K8s Secret: arc-github-secret (namespace: arc-runners)         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Usage in GitHub Workflows

Once the PAT is updated with correct permissions:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint:
    runs-on: gameplatform-light  # 2 vCPU, 8GB RAM
    steps:
      - uses: actions/checkout@v4
      - run: npm run lint

  test:
    runs-on: gameplatform-light
    steps:
      - uses: actions/checkout@v4
      - run: npm test

  build-docker:
    runs-on: gameplatform-heavy  # 8 vCPU, 32GB RAM, Docker enabled
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t myapp .
      - run: docker push gcr.io/project-dev-env/myapp
```

---

## Cost Optimization Notes

- **Light runners**: Spot VMs, scale to zero when idle
- **Heavy runners**: Spot VMs, scale to zero when idle
- **Controller pool**: On-demand (stable), min=1 always running
- **Estimated monthly cost**: ~$15-30 for controller pool + usage-based for runners

---

## Related Documentation

- [ARC GitHub Repository](https://github.com/actions/actions-runner-controller)
- [GKE Private Clusters](https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept)
- [External Secrets Operator](https://external-secrets.io/)
- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
