# External Secrets Operator (ESO)

Syncs secrets from GCP Secret Manager to Kubernetes Secrets using GKE Workload Identity.

## Overview

External Secrets Operator (ESO) provides a Kubernetes-native way to sync secrets from external secret stores (like GCP Secret Manager) into Kubernetes Secrets. This eliminates the need to manually create and manage secrets in the cluster.

**Features**:
- Automatic synchronization from GCP Secret Manager
- Workload Identity authentication (no service account keys)
- Automatic secret rotation based on refresh interval
- ClusterSecretStore for cross-namespace access

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   GCP Secret Manager                        │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │
│  │ github-arc-pat│  │ nakama-config │  │ lobby-config  │   │
│  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘   │
└──────────┼──────────────────┼──────────────────┼───────────┘
           │                  │                  │
           │ Workload Identity (auto-sync)       │
           ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
│  ┌───────────────────────────────────────────────────────┐ │
│  │         External Secrets Operator (ESO)               │ │
│  │  - Watches ExternalSecret resources                   │ │
│  │  - Fetches from GCP Secret Manager                    │ │
│  │  - Creates/updates Kubernetes Secrets                 │ │
│  └───────────────────────────────────────────────────────┘ │
│                          │                                  │
│                          ▼                                  │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │
│  │ K8s Secret    │  │ K8s Secret    │  │ K8s Secret    │   │
│  │ (arc-github)  │  │ (nakama)      │  │ (lobby)       │   │
│  └───────────────┘  └───────────────┘  └───────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **GCP Secret Manager secrets created** via 06-workloads stack
2. **ESO service accounts created** via 06-workloads stack
3. **kubectl** connected to target cluster
4. **Helm v3+** installed

## Installation

### Workloads Cluster (DEV)

```bash
# Connect to dev workloads cluster (via VPN - cluster is private)
gcloud container clusters get-credentials project-dev-workloads \
  --region us-east1 \
  --project project-nonprod-env \
  --internal-ip

# Install ESO
cd charts/external-secrets
./install.sh workloads
```

### Workloads Cluster (STG)

```bash
# Connect to stg workloads cluster (via VPN - cluster is private)
gcloud container clusters get-credentials project-stg-workloads \
  --region us-east1 \
  --project project-nonprod-env \
  --internal-ip

# Install ESO
cd charts/external-secrets
./install.sh workloads
```

### Runners Cluster

```bash
# Connect to runners cluster (via VPN - cluster is private)
gcloud container clusters get-credentials gameplatform-nonprod-runners \
  --region us-east1 \
  --project project-nonprod-env \
  --internal-ip

# Install ESO
cd charts/external-secrets
./install.sh runners
```

## Verify Installation

```bash
# Check ESO pods
kubectl get pods -n external-secrets

# Check ClusterSecretStore
kubectl get clustersecretstore

# Check ClusterSecretStore status
kubectl describe clustersecretstore gcp-secret-manager
```

## Creating ExternalSecrets

After ESO is installed, create ExternalSecret resources to sync secrets:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: my-secret
  namespace: my-namespace
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: gcp-secret-manager
  target:
    name: my-secret  # K8s Secret name
    creationPolicy: Owner
  data:
    - secretKey: password  # Key in K8s Secret
      remoteRef:
        key: project-dev-my-secret  # GCP Secret Manager secret name
```

## Uninstall

```bash
./install.sh --uninstall
```

## Important Notes

### Secret Value Format

⚠️ **CRITICAL**: When storing secrets in GCP Secret Manager, always use `printf '%s'` instead of `echo` to avoid trailing newlines:

```bash
# CORRECT - no trailing newline
printf '%s' "secret_value" | gcloud secrets versions add SECRET_NAME \
  --data-file=- --project=PROJECT_ID

# WRONG - echo adds a newline which can break authentication headers
echo "secret_value" | gcloud secrets versions add ...
```

### GKE Private Cluster Requirements

For ESO to work in GKE private clusters, the **konnectivity-agent** system pods must be running. These pods handle communication between the control plane and nodes.

The node pool hosting ESO must use one of these taints that konnectivity-agent tolerates:
- `components.gke.io/gke-managed-components=true:NoSchedule` (recommended)
- `CriticalAddonsOnly=true:NoSchedule`

Custom taints like `dedicated=something:NoSchedule` will prevent konnectivity-agent from scheduling, causing webhook timeouts.

## Troubleshooting

### ESO not syncing

```bash
# Check ESO logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets

# Check ExternalSecret status
kubectl describe externalsecret <name> -n <namespace>

# Check ClusterSecretStore status
kubectl describe clustersecretstore gcp-secret-manager
```

### Webhook "No agent available" Error

This error indicates konnectivity-agent isn't running:

```bash
# Check konnectivity-agent pods
kubectl get pods -n kube-system -l k8s-app=konnectivity-agent

# If pending, check node taints
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.taints}{"\n"}{end}'
```

**Solution**: Update node pool taint to `components.gke.io/gke-managed-components=true:NoSchedule`

### Secret Sync Timeout

If you see `context deadline exceeded`:

1. **Check konnectivity-agent** is running (see above)
2. **Verify IAM permissions**:
   ```bash
   # Check if ESO service account has access to the secret
   gcloud secrets get-iam-policy SECRET_NAME --project=PROJECT_ID
   ```
3. **Add secret-level IAM binding** if needed:
   ```bash
   gcloud secrets add-iam-policy-binding SECRET_NAME \
     --project=PROJECT_ID \
     --member="serviceAccount:ESO_SERVICE_ACCOUNT@PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/secretmanager.secretAccessor"
   ```

### Workload Identity Issues

```bash
# Verify service account annotation
kubectl get sa external-secrets -n external-secrets -o yaml

# Check the iam.gke.io/gcp-service-account annotation matches Terraform output

# Test Secret Manager access from within the cluster
kubectl run test-sm --rm -i --tty \
  --image=google/cloud-sdk:slim \
  --overrides='{"spec":{"serviceAccountName":"external-secrets"}}' \
  -n external-secrets -- bash

# Inside the pod:
gcloud secrets versions access latest --secret=gameplatform-nonprod-github-arc-pat
```

### Force Secret Resync

```bash
# Trigger immediate resync
kubectl annotate externalsecret EXTERNAL_SECRET_NAME -n NAMESPACE \
  force-sync=$(date +%s) --overwrite
```

## Files

```
charts/external-secrets/
├── README.md                    # This file
├── install.sh                   # Installation script
├── values.yaml                  # Base values
├── values-workloads.yaml        # Workloads cluster values
├── values-runners.yaml          # Runners cluster values
└── cluster-secret-store.yaml    # ClusterSecretStore for GCP
```
