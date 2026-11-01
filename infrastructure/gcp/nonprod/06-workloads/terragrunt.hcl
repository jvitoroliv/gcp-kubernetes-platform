# =============================================================================
# 06-WORKLOADS STACK - NONPROD ENVIRONMENT
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
  config_path = "../08-gke-runners"

  mock_outputs = {
    cluster_name     = "gameplatform-nonprod-runners"
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
      description            = "Shared runner and CI/CD images - nonprod"
      format                 = "DOCKER"
      cleanup_policy_dry_run = false
      cleanup_policies = [
        {
          id     = "delete-untagged"
          action = "DELETE"
          condition = {
            tag_state  = "UNTAGGED"
            older_than = "604800s" # 7 days
          }
        },
        {
          id     = "keep-recent"
          action = "KEEP"
          most_recent_versions = {
            keep_count = 10
          }
        }
      ]
    }
  }

  # Secret Manager - Pre-created secrets for runners
  secrets = {
    github-arc-pat = {
      description = "GitHub PAT for Actions Runner Controller (ARC)"
      replication = "automatic"
      labels = {
        application = "arc"
        component   = "runners"
      }
    }
  }

  # External Secrets Operator - Service accounts for ESO in runners cluster
  enable_external_secrets = true

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
    "gameplatform-shared-infrastructure-gcp",
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

  # Monitoring - Disabled for nonprod
  enable_alerting = false

  labels = {
    environment = "nonprod"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "shared"
  }
}
