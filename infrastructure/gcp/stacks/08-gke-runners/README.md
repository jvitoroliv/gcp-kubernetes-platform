# 08 - GKE Runners Stack

This stack deploys a dedicated GKE cluster for GitHub Actions self-hosted runners.

## Overview

Creates a separate GKE cluster optimized for CI/CD workloads with:
- Scale-to-zero runner pools for cost efficiency
- Spot VMs for runner pools (60-90% cost savings)
- Dedicated controller pool (always running)
- Workload Identity for secure GCP authentication
- Integration with External Secrets Operator for GitHub PAT management

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   project-dev-runners cluster                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  arc-controller pool                                     │    │
│  │  - Machine: e2-small                                     │    │
│  │  - Nodes: 1-3                                            │    │
│  │  - Spot: No (stable)                                     │    │
│  │  - Taint: components.gke.io/gke-managed-components=true  │    │
│  │  - Purpose: ARC controller, listeners, ESO, system pods  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  runners-light pool                                      │    │
│  │  - Machine: e2-standard-2 (2 vCPU, 8GB)                  │    │
│  │  - Nodes: 0-5                                            │    │
│  │  - Spot: Yes                                             │    │
│  │  - Taint: runner-type=light:NoSchedule                   │    │
│  │  - Purpose: Lint, tests, simple CI jobs                  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  runners-heavy pool                                      │    │
│  │  - Machine: e2-standard-8 (8 vCPU, 32GB)                 │    │
│  │  - Nodes: 0-5                                            │    │
│  │  - Spot: Yes                                             │    │
│  │  - Taint: runner-type=heavy:NoSchedule                   │    │
│  │  - Purpose: Docker builds, resource-intensive jobs       │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

Before deploying this stack:

1. **02-networking** stack must be applied (VPC, subnets)
2. Secondary IP ranges for pods/services configured in 02-networking
3. GKE node service account created (from 03-gke or separate)

## Resources Created

- GKE cluster (`gameplatform-{env}-runners`)
- Node pool: `gameplatform-{env}-arc-controller` (min=1, on-demand)
- Node pool: `gameplatform-{env}-runners-light` (min=0, spot)
- Node pool: `gameplatform-{env}-runners-heavy` (min=0, spot)
- Workload Identity SA: `gameplatform-{env}-arc-controller`
- Workload Identity SA: `gameplatform-{env}-arc-runner`
- Firewall rule: `gameplatform-{env}-allow-github-webhooks`

## Configuration

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `light_pool_min_nodes` | Minimum light runner nodes | 0 |
| `light_pool_max_nodes` | Maximum light runner nodes | 5 |
| `light_pool_machine_type` | Light pool machine type | e2-standard-2 |
| `heavy_pool_min_nodes` | Minimum heavy runner nodes | 0 |
| `heavy_pool_max_nodes` | Maximum heavy runner nodes | 5 |
| `heavy_pool_machine_type` | Heavy pool machine type | e2-standard-8 |
| `controller_pool_min_nodes` | Minimum controller nodes | 1 |
| `controller_pool_max_nodes` | Maximum controller nodes | 3 |
| `controller_pool_machine_type` | Controller pool machine type | e2-small |
| `master_ipv4_cidr` | Master CIDR block | 172.16.1.0/28 |

### Terragrunt Configuration

```hcl
# dev/08-gke-runners/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_parent_terragrunt_dir()}/stacks/08-gke-runners"
}

dependency "networking" {
  config_path = "../02-networking"
}

inputs = {
  vpc_self_link    = dependency.networking.outputs.vpc_self_link
  subnet_self_link = dependency.networking.outputs.subnet_self_link
  vpc_name         = dependency.networking.outputs.vpc_name

  # Secondary ranges for runners
  pods_range_name     = "runners-pods"
  services_range_name = "runners-services"

  # Master CIDR (must not overlap with workloads cluster)
  master_ipv4_cidr = "172.16.1.0/28"
}
```

## Node Pool Taints

### Controller Pool

Uses `components.gke.io/gke-managed-components=true:NoSchedule` which:
- Allows GKE system components (konnectivity-agent, etc.)
- Prevents regular workloads from scheduling
- Requires explicit toleration for user workloads

### Runner Pools

- Light: `runner-type=light:NoSchedule`
- Heavy: `runner-type=heavy:NoSchedule`

These ensure only the appropriate runner pods schedule on each pool.

## Workload Identity

Two service accounts are created for Workload Identity:

### ARC Controller SA

- Name: `gameplatform-{env}-arc-controller`
- K8s SA: `arc-gha-rs-controller` in `arc-systems` namespace
- Roles:
  - `roles/logging.logWriter`
  - `roles/monitoring.metricWriter`

### ARC Runner SA

- Name: `gameplatform-{env}-arc-runner`
- K8s SA: `arc-runner` in `arc-runners` namespace
- Roles:
  - `roles/artifactregistry.writer`
  - `roles/artifactregistry.reader`
  - `roles/storage.objectViewer`
  - `roles/secretmanager.secretAccessor`
  - `roles/container.developer`

## Firewall Rules

### GitHub Webhooks

Allows GitHub to send webhook events to the ARC controller:

```hcl
source_ranges = [
  "192.30.252.0/22",
  "185.199.108.0/22",
  "140.82.112.0/20",
  "143.55.64.0/20",
]
ports = ["443", "80"]
```

## Post-Deployment

After the GKE cluster is created:

1. **Connect to cluster**:
   ```bash
   gcloud container clusters get-credentials project-dev-runners \
     --region southamerica-east1 \
     --project project-dev-env
   ```

2. **Install External Secrets Operator**:
   ```bash
   cd platform-kubernetes-infrastructure/charts/external-secrets
   ./install.sh runners
   ```

3. **Store GitHub PAT in Secret Manager**:

   ⚠️ **IMPORTANT**: Use `printf '%s'` instead of `echo` to avoid trailing newlines that break authentication.

   ```bash
   # CORRECT - no trailing newline
   printf '%s' "ghp_your_token" | gcloud secrets versions add project-dev-github-arc-pat \
     --data-file=- --project=project-dev-env

   # WRONG - echo adds newline
   # echo "ghp_your_token" | gcloud secrets versions add ...
   ```

4. **Install ARC**:
   ```bash
   cd platform-kubernetes-infrastructure/charts/runners
   ./install.sh
   ```

See `platform-kubernetes-infrastructure/charts/runners/README.md` for detailed instructions.

## Cost Optimization

- **Controller pool**: ~$15-20/month (always on, small instances)
- **Runner pools**: Pay per use (scale to zero, spot instances)
- **Spot VMs**: 60-90% cheaper than on-demand
- **Estimated monthly**: $15-30 base + usage

## Maintenance

### Update Node Pool

```bash
# Update controller pool machine type
gcloud container node-pools update project-dev-arc-controller \
  --cluster project-dev-runners \
  --region southamerica-east1 \
  --machine-type e2-medium
```

### Resize Node Pool

```bash
# Scale light runners max nodes
gcloud container clusters resize project-dev-runners \
  --node-pool project-dev-runners-light \
  --num-nodes 3 \
  --region southamerica-east1
```

## Troubleshooting

### konnectivity-agent Pending

If system pods are stuck in Pending, check node taints:

```bash
kubectl get nodes -o jsonpath='{.items[*].spec.taints}'
```

The controller pool must use `components.gke.io/gke-managed-components` taint (not custom taints).

### Nodes Not Scaling

Check cluster autoscaler logs:

```bash
kubectl logs -n kube-system -l k8s-app=cluster-autoscaler
```

### Network Connectivity

Verify firewall rules allow master-to-node communication:

```bash
gcloud compute firewall-rules list --filter="name~runners"
```

## Related Stacks

- `02-networking`: VPC and subnet configuration
- `06-workloads`: External Secrets service accounts
