# gameplatform-shared-infrastructure-gcp

Centralized Infrastructure-as-Code for GamePlatform's GCP platform using Terragrunt. This repository manages shared infrastructure services including networking, GKE clusters, databases, DNS, load balancing, and supporting resources.

## Architecture Overview

### NONPROD Environment (dev + stg + shared resources)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GCP Project: project-nonprod-env                          │
│                           Region: us-east1                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                   SHARED VPC: gameplatform-nonprod-vpc                      │  │
│  │                                                                        │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐    │  │
│  │  │ DEV Subnet      │  │ STG Subnet      │  │ RUNNERS Subnet      │    │  │
│  │  │ 10.100.0.0/20   │  │ 10.48.0.0/20    │  │ 10.120.0.0/20       │    │  │
│  │  │                 │  │                 │  │                     │    │  │
│  │  │ project-dev-     │  │ project-stg-     │  │ gameplatform-nonprod-     │    │  │
│  │  │ workloads (GKE) │  │ workloads (GKE) │  │ runners (GKE)       │    │  │
│  │  │ - Namespace:    │  │ - Namespace:    │  │ - ArgoCD            │    │  │
│  │  │   gameplatform-dev    │  │   gameplatform-stg    │  │ - ARC Controller    │    │  │
│  │  │ - ESO           │  │ - ESO           │  │ - ARC Runners       │    │  │
│  │  │ - 8 Services    │  │ - 8 Services    │  │ - ESO               │    │  │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────┘    │  │
│  │                                                                        │  │
│  │  Cloud SQL: postgres-dev, postgres-stg                                 │  │
│  │  Cloud DNS: *.dev.gameplatform (internal), *.stg.gameplatform (internal)          │  │
│  │  Cloud NAT: Outbound internet access                                   │  │
│  │  WireGuard VPN: Bastion host for admin access                          │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### PRD Environment (production)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     GCP Project: project-prd-env                             │
│                     Region: southamerica-east1                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  project-prd-vpc                                                             │
│  ├── project-prd-workloads (GKE) - Namespace: gameplatform-prd                    │
│  ├── Cloud SQL: postgres-prd                                                │
│  ├── Cloud DNS: *.gameplatform.example.com (public)                                     │
│  └── Global Load Balancer with Cloud Armor                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
.
├── terragrunt.hcl                   # Root Terragrunt configuration
│
├── dev/                             # DEV environment stacks
│   ├── env.hcl                      # Dev environment variables
│   ├── 01-foundation/terragrunt.hcl
│   ├── 03-gke/terragrunt.hcl
│   ├── 04-database/terragrunt.hcl
│   ├── 05-dns-lb/terragrunt.hcl
│   └── 06-workloads/terragrunt.hcl
│
├── stg/                             # STG environment stacks
│   ├── env.hcl                      # Stg environment variables
│   ├── 01-foundation/terragrunt.hcl
│   ├── 03-gke/terragrunt.hcl
│   ├── 04-database/terragrunt.hcl
│   ├── 05-dns-lb/terragrunt.hcl
│   └── 06-workloads/terragrunt.hcl
│
├── nonprod/                         # NONPROD shared resources
│   ├── env.hcl                      # Nonprod environment variables
│   ├── 02-networking/terragrunt.hcl # Shared VPC for dev + stg + runners
│   ├── 07-vpn-bastion/terragrunt.hcl
│   └── 08-gke-runners/terragrunt.hcl
│
├── prd/                             # PRD environment stacks
│   ├── env.hcl                      # Prd environment variables
│   ├── 01-foundation/terragrunt.hcl
│   ├── 02-networking/terragrunt.hcl # Separate VPC for prd
│   ├── 03-gke/terragrunt.hcl
│   ├── 04-database/terragrunt.hcl
│   ├── 05-dns-lb/terragrunt.hcl
│   ├── 06-workloads/terragrunt.hcl
│   ├── 07-vpn-bastion/terragrunt.hcl
│   └── 08-gke-runners/terragrunt.hcl
│
├── stacks/                          # Terraform modules (source)
│   ├── 01-foundation/
│   ├── 02-networking/
│   ├── 02-networking-shared/        # Shared VPC module for nonprod
│   ├── 03-gke/
│   ├── 04-database/
│   ├── 05-dns-lb/
│   ├── 06-workloads/
│   ├── 07-vpn-bastion/
│   └── 08-gke-runners/
│
└── scripts/                         # Helper scripts
    └── wireguard/                   # VPN setup scripts
```

## Terraform State

State files are stored in GCS buckets with separate buckets per project:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ gs://gameplatform-nonprod-terraform-state (in project-nonprod-env)             │
│ ├── dev/01-foundation/terraform.tfstate                                 │
│ ├── dev/03-gke/terraform.tfstate                                        │
│ ├── dev/04-database/terraform.tfstate                                   │
│ ├── dev/05-dns-lb/terraform.tfstate                                     │
│ ├── dev/06-workloads/terraform.tfstate                                  │
│ ├── stg/01-foundation/terraform.tfstate                                 │
│ ├── stg/03-gke/terraform.tfstate                                        │
│ ├── stg/04-database/terraform.tfstate                                   │
│ ├── stg/05-dns-lb/terraform.tfstate                                     │
│ ├── stg/06-workloads/terraform.tfstate                                  │
│ ├── nonprod/02-networking/terraform.tfstate  (shared VPC)               │
│ ├── nonprod/07-vpn-bastion/terraform.tfstate                            │
│ └── nonprod/08-gke-runners/terraform.tfstate                            │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ gs://project-prd-terraform-state (in project-prd-env)                     │
│ ├── prd/01-foundation/terraform.tfstate                                 │
│ ├── prd/02-networking/terraform.tfstate                                 │
│ ├── prd/03-gke/terraform.tfstate                                        │
│ ├── prd/04-database/terraform.tfstate                                   │
│ ├── prd/05-dns-lb/terraform.tfstate                                     │
│ ├── prd/06-workloads/terraform.tfstate                                  │
│ ├── prd/07-vpn-bastion/terraform.tfstate                                │
│ └── prd/08-gke-runners/terraform.tfstate                                │
└─────────────────────────────────────────────────────────────────────────┘
```

## Stacks

### 01-foundation
Enables GCP APIs and creates IAM service accounts:
- Enables required GCP APIs (Compute, Container, SQL, etc.)
- GKE node service account
- Cloud SQL admin service account
- Workload Identity service accounts for applications

### 02-networking
Core networking infrastructure:
- VPC with custom mode
- Subnet with secondary ranges for GKE pods/services
- Cloud Router and Cloud NAT for internet access
- Firewall rules (internal, health checks, IAP, GKE master)
- Private Service Connection for Cloud SQL

### 03-gke
Google Kubernetes Engine cluster:
- Private VPC-native cluster
- Multiple node pools (general, game-servers)
- Workload Identity bindings for applications
- Managed Prometheus (production)

### 04-database
Cloud SQL PostgreSQL:
- High availability (Regional)
- Private IP access only
- Automated backups with PITR
- Databases: nakama, lobby
- Credentials stored in Secret Manager

### 05-dns-lb
DNS and Load Balancing:
- Cloud DNS zones
- Global HTTP(S) Load Balancer
- Google-managed SSL certificates
- Cloud CDN (production)
- Cloud Armor security policies (production)

### 06-workloads
Supporting infrastructure for workloads:
- Artifact Registry for container images
- Secret Manager secrets
- GitHub Actions OIDC authentication
- Monitoring alert policies

## Environments

| Environment | Description | Key Differences |
|-------------|-------------|-----------------|
| **dev** | Development | Smaller instances, preemptible nodes, minimal backups |
| **stg** | Staging | **Same size as production** for parity testing |
| **prd** | Production | Full HA, extensive monitoring, Cloud Armor enabled |

> **Important**: Staging environment has the **same configuration and sizing** as production to ensure accurate testing and validation before deploying to prd.

## Prerequisites

1. **GCP Projects**:
   - `project-nonprod-env` for dev/stg/nonprod
   - `project-prd-env` for production
2. **gcloud CLI**: Install and authenticate
3. **Terraform**: Version >= 1.13
4. **Terragrunt**: Version >= 0.50
5. **IAM Permissions**: `roles/owner` or equivalent for initial setup

## Quick Start (with Terragrunt)

### 1. Create State Buckets

```bash
# NONPROD bucket (for dev, stg, and nonprod shared resources)
gsutil mb -p project-nonprod-env -l us-east1 gs://gameplatform-nonprod-terraform-state
gsutil versioning set on gs://gameplatform-nonprod-terraform-state

# PRD bucket (create when setting up production)
# gsutil mb -p project-prd-env -l southamerica-east1 gs://project-prd-terraform-state
# gsutil versioning set on gs://project-prd-terraform-state
```

### 2. Deploy a Stack

```bash
cd ~/Documents/GamePlatform/Repos/gameplatform-shared-infrastructure-gcp

# Deploy DEV foundation
cd dev/01-foundation
terragrunt init
terragrunt plan
terragrunt apply
```

### 3. Plan Changes

```bash
# Plan changes for a specific stack
cd stg/03-gke
terragrunt plan
```

## Deployment Order

### NONPROD (dev + stg + shared resources)

Stacks must be deployed in this order:

```
nonprod/02-networking (shared VPC)
       │
       ├── dev/01-foundation → dev/03-gke → dev/04-database → dev/05-dns-lb → dev/06-workloads
       │
       ├── stg/01-foundation → stg/03-gke → stg/04-database → stg/05-dns-lb → stg/06-workloads
       │
       └── nonprod/07-vpn-bastion → nonprod/08-gke-runners
```

### First-time NONPROD Deployment

```bash
cd ~/Documents/GamePlatform/Repos/gameplatform-shared-infrastructure-gcp

# 1. NETWORKING (shared VPC - must be first)
cd nonprod/02-networking && terragrunt init && terragrunt apply -auto-approve && cd ../..

# 2. DEV STACKS
cd dev/01-foundation && terragrunt init && terragrunt apply -auto-approve && cd ../..
cd dev/03-gke && terragrunt init && terragrunt apply -auto-approve && cd ../..
cd dev/04-database && terragrunt init && terragrunt apply -auto-approve && cd ../..
cd dev/05-dns-lb && terragrunt init && terragrunt apply -auto-approve && cd ../..
cd dev/06-workloads && terragrunt init && terragrunt apply -auto-approve && cd ../..

# 3. STG STACKS
cd stg/01-foundation && terragrunt init && terragrunt apply -auto-approve && cd ../..
cd stg/03-gke && terragrunt init && terragrunt apply -auto-approve && cd ../..
cd stg/04-database && terragrunt init && terragrunt apply -auto-approve && cd ../..
cd stg/05-dns-lb && terragrunt init && terragrunt apply -auto-approve && cd ../..
cd stg/06-workloads && terragrunt init && terragrunt apply -auto-approve && cd ../..

# 4. SHARED SERVICES
cd nonprod/07-vpn-bastion && terragrunt init && terragrunt apply -auto-approve && cd ../..
cd nonprod/08-gke-runners && terragrunt init && terragrunt apply -auto-approve && cd ../..
```

### PRD Deployment (separate project)

```bash
# First create the state bucket
gsutil mb -p project-prd-env -l southamerica-east1 gs://project-prd-terraform-state
gsutil versioning set on gs://project-prd-terraform-state

# Then deploy PRD stacks
cd prd/01-foundation && terragrunt init && terragrunt apply -auto-approve && cd ../..
cd prd/02-networking && terragrunt init && terragrunt apply -auto-approve && cd ../..
# ... etc
```

## CI/CD with Atlantis

This repository is configured to work with Atlantis for Terraform automation.

### Workflow

1. Create a PR with infrastructure changes
2. Atlantis automatically runs `terraform plan`
3. Review the plan output in the PR comments
4. Approve the PR
5. Comment `atlantis apply` to apply changes
6. Merge the PR after successful apply

### Apply Requirements

| Environment | Requirements |
|-------------|--------------|
| dev | `approved` |
| stg | `approved` |
| prd | `approved`, `mergeable` |

## Integration with Kubernetes

This infrastructure integrates with `platform-kubernetes-infrastructure`:

### Workload Identity

GKE pods use Workload Identity to access GCP services:

```yaml
# In Kubernetes ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nakama
  namespace: gameplatform
  annotations:
    iam.gke.io/gcp-service-account: project-prd-nakama@project-prd-env.iam.gserviceaccount.com
```

### External Secrets

Secrets are stored in GCP Secret Manager and synced to Kubernetes:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
spec:
  secretStoreRef:
    name: gcp-secret-manager
    kind: ClusterSecretStore
  target:
    name: database-credentials
  data:
    - secretKey: connection-string
      remoteRef:
        key: project-prd-db-nakama-connection
```

### GitHub Actions

Push container images using OIDC authentication:

```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
    service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

- name: Push to Artifact Registry
  run: |
    gcloud auth configure-docker southamerica-east1-docker.pkg.dev
    docker push southamerica-east1-docker.pkg.dev/project-prd-env/project-prd-gameplatform/nakama:latest
```

## Module Source

All stacks use modules from the `gameplatform-terraform` repository:

```hcl
module "vpc" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/vpc"
  # ...
}
```

## Cost Optimization

### Development Environment
- Preemptible/Spot GKE nodes
- Smaller Cloud SQL instance (db-custom-1-3840)
- Minimal backup retention
- VPC Flow Logs with low sampling

### Stg/Prd Environments
- Standard GKE nodes (no preemptible)
- Larger Cloud SQL instance (db-custom-4-16384)
- Regional HA for Cloud SQL
- Full monitoring and alerting

## Security

- **Private GKE Cluster**: Nodes have no public IPs
- **Private Cloud SQL**: Accessible only via VPC
- **Workload Identity**: No service account keys
- **Cloud Armor**: WAF protection for production
- **Secret Manager**: Encrypted secrets with IAM access control
- **GitHub OIDC**: Keyless authentication from CI/CD

## Troubleshooting

### Common Issues

1. **State Lock Error**
   ```bash
   # Force unlock (use with caution)
   terraform force-unlock LOCK_ID
   ```

2. **Module Source Issues**
   ```bash
   # Clear module cache
   rm -rf .terraform/modules
   terraform init
   ```

3. **Permission Denied**
   - Verify IAM permissions in GCP Console
   - Check Workload Identity configuration

## Related Repositories

- [gameplatform-terraform](https://github.com/example-gamedev-org/gameplatform-terraform) - Terraform modules
- [platform-kubernetes-infrastructure](https://github.com/example-gamedev-org/platform-kubernetes-infrastructure) - Helm charts and Kubernetes config
- [gameplatform-shared-infrastructure](https://github.com/example-gamedev-org/gameplatform-shared-infrastructure) - AWS infrastructure (legacy)
