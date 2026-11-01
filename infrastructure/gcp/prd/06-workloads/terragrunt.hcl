# =============================================================================
# 06-WORKLOADS STACK - PRD ENVIRONMENT
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
    cluster_name     = "project-prd-workloads"
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
      description            = "GamePlatform container images - prd"
      format                 = "DOCKER"
      cleanup_policy_dry_run = false
      cleanup_policies = [
        {
          id     = "delete-untagged"
          action = "DELETE"
          condition = {
            tag_state  = "UNTAGGED"
            older_than = "2592000s" # 30 days for prd
          }
        },
        {
          id     = "keep-recent"
          action = "KEEP"
          most_recent_versions = {
            keep_count = 20
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
  }

  # External Secrets Operator
  enable_external_secrets = true

  # Cert-Manager Service Account for DNS-01 challenge
  cert_manager_service_account = {
    enabled             = true
    name                = "project-prd-cert-manager"
    namespace           = "cert-manager"
    k8s_service_account = "cert-manager-prd"
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
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/secretmanager.admin",
    "roles/iam.securityAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/editor",
    "roles/servicenetworking.networksAdmin",
  ]

  # Monitoring - Enabled for prd
  enable_alerting = true

  labels = {
    environment = "prd"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "production"
  }
}
