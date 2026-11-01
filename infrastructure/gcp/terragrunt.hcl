# =============================================================================
# ROOT TERRAGRUNT CONFIGURATION
# =============================================================================
# This is the root terragrunt.hcl that all other terragrunt.hcl files include.
# It defines common configurations like remote state and provider settings.
#
# STATE BUCKET ARCHITECTURE:
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ gameplatform-nonprod-terraform-state (bucket in project-nonprod-env)           │
# │ ├── dev/01-foundation/terraform.tfstate                                 │
# │ ├── dev/03-gke/terraform.tfstate                                        │
# │ ├── dev/04-database/terraform.tfstate                                   │
# │ ├── dev/.../terraform.tfstate                                           │
# │ ├── stg/01-foundation/terraform.tfstate                                 │
# │ ├── stg/03-gke/terraform.tfstate                                        │
# │ ├── stg/.../terraform.tfstate                                           │
# │ ├── nonprod/02-networking/terraform.tfstate (shared VPC)                │
# │ ├── nonprod/07-vpn-bastion/terraform.tfstate                            │
# │ └── nonprod/08-gke-runners/terraform.tfstate                            │
# └─────────────────────────────────────────────────────────────────────────┘
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ gameplatform-terraform-state-prd (bucket in project-prd-env)                   │
# │ ├── prd/01-foundation/terraform.tfstate                                 │
# │ ├── prd/02-networking/terraform.tfstate                                 │
# │ ├── prd/03-gke/terraform.tfstate                                        │
# │ └── prd/.../terraform.tfstate                                           │
# └─────────────────────────────────────────────────────────────────────────┘

locals {
  # Parse the path to extract environment and stack
  path_parts = split("/", path_relative_to_include())

  # Environment is the first directory (dev, stg, prd, nonprod)
  environment = local.path_parts[0]

  # Stack is the second directory (01-foundation, 02-networking, etc.)
  stack = local.path_parts[1]

  # Determine which GCP project to use based on environment
  # - prd uses project-prd-env
  # - legacy uses project-legacy-env
  # - dev, stg, nonprod use project-nonprod-env
  gcp_project = (
    local.environment == "prd" ? "project-prd-env" :
    local.environment == "legacy" ? "project-legacy-env" :
    "project-nonprod-env"
  )

  # Determine which state bucket to use
  # - prd uses separate bucket in prd project
  # - legacy uses separate bucket in legacy project
  # - dev, stg, nonprod share bucket in nonprod project (with separate prefixes)
  state_bucket = (
    local.environment == "prd" ? "gameplatform-terraform-state-prd" :
    local.environment == "legacy" ? "gameplatform-terraform-state-legacy" :
    "gameplatform-nonprod-terraform-state"
  )

  # State prefix format: {environment}/{stack}
  # Examples:
  # - dev/01-foundation
  # - stg/03-gke
  # - nonprod/02-networking
  # - prd/01-foundation
  state_prefix = "${local.environment}/${local.stack}"

  # Common tags for all resources
  common_tags = {
    ManagedBy   = "terragrunt"
    Environment = local.environment
    Project     = "gameplatform"
  }
}

# =============================================================================
# REMOTE STATE CONFIGURATION
# =============================================================================
# State is stored in GCS buckets:
# - nonprod bucket: gs://gameplatform-nonprod-terraform-state (dev, stg, nonprod)
# - prd bucket: gs://gameplatform-terraform-state-prd (prd only)
#
# IMPORTANT: The prd bucket must be created manually before applying prd stacks:
#   gsutil mb -p project-prd-env -l southamerica-east1 gs://gameplatform-terraform-state-prd
#   gsutil versioning set on gs://gameplatform-terraform-state-prd
#
remote_state {
  backend = "gcs"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket  = local.state_bucket
    prefix  = local.state_prefix
    project = local.gcp_project
  }
}

# =============================================================================
# GENERATE PROVIDER CONFIGURATION
# =============================================================================
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.13.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  # Region is set via inputs based on environment
}

provider "google-beta" {
  # Region is set via inputs based on environment
}
EOF
}

# =============================================================================
# INPUT DEFAULTS
# =============================================================================
inputs = {
  environment = local.environment
  # prd and legacy use southamerica-east1, dev/stg use us-east1
  region      = contains(["prd", "legacy"], local.environment) ? "southamerica-east1" : "us-east1"

  labels = local.common_tags
}
