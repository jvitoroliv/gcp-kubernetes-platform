# =============================================================================
# 06-WORKLOADS STACK - DEV ENVIRONMENT
# =============================================================================

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/06-workloads"
}

dependency "gke" {
  config_path = "../03-gke"

  mock_outputs = {
    cluster_name     = "project-dev-workloads"
    cluster_endpoint = "https://172.16.0.2"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Artifact Registry
  artifact_registries = {
    images = {
      description            = "GamePlatform container images - dev"
      format                 = "DOCKER"
      cleanup_policy_dry_run = false
      cleanup_policies = [
        {
          id     = "delete-untagged"
          action = "DELETE"
          condition = {
            tag_state  = "UNTAGGED"
            older_than = "259200s" # 3 days for dev
          }
        },
        {
          id     = "keep-recent"
          action = "KEEP"
          most_recent_versions = {
            keep_count = 5 # Keep fewer versions in dev
          }
        }
      ]
    }
  }

  # Secret Manager - Pre-created secrets
  secrets = {
    nakama-config = {
      description = "Nakama server configuration"
      replication = "automatic"
      labels = {
        application = "nakama"
      }
    }
    lobby-config = {
      description = "Lobby backend configuration"
      replication = "automatic"
      labels = {
        application = "lobby"
      }
    }
    github-arc-pat = {
      description = "GitHub PAT for Actions Runner Controller (ARC)"
      replication = "automatic"
      labels = {
        application = "arc"
        component   = "runners"
      }
    }
    gcs-access-key = {
      description = "GCS HMAC access key for S3-compatible API"
      replication = "automatic"
      labels = {
        application = "ais"
        component   = "storage"
      }
    }
    gcs-secret-key = {
      description = "GCS HMAC secret key for S3-compatible API"
      replication = "automatic"
      labels = {
        application = "ais"
        component   = "storage"
      }
    }
  }

  # External Secrets Operator - Service accounts for ESO in each cluster
  enable_external_secrets = true

  # Cert-Manager Service Account for DNS-01 challenge
  cert_manager_service_account = {
    enabled            = true
    name               = "project-dev-cert-manager"
    namespace          = "cert-manager"
    k8s_service_account = "cert-manager-dev"
  }

  # GitHub Actions OIDC
  enable_github_oidc = true
  github_org         = "example-gamedev-org"
  github_oidc_repos = [
    "gameplatform-monorepo",
    "nakama",
    "lobby-backend",
    "afs",
    "ahsat",
    "aes",
    "ais",
    "platform-kubernetes-infrastructure",
  ]
  github_oidc_service_account_roles = [
    "roles/artifactregistry.writer",
    "roles/container.developer",
    "roles/storage.admin",
    "roles/iam.serviceAccountAdmin",           # Required for Workload Identity bindings
    "roles/resourcemanager.projectIamAdmin",   # Required for project IAM policy changes
    "roles/secretmanager.admin",               # Required for Secret Manager operations
  ]

  # Monitoring - Disabled for dev
  enable_alerting = false

  labels = {
    environment = "dev"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "development"
  }
}
