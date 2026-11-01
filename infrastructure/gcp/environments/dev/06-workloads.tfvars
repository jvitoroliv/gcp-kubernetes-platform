# =============================================================================
# DEV ENVIRONMENT - WORKLOADS STACK
# =============================================================================

project_id  = "project-nonprod-env"
environment = "dev"
region      = "us-east1"

# Artifact Registry
artifact_registries = {
  gameplatform = {
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
}

# GitHub Actions OIDC
enable_github_oidc = true
github_org         = "example-gamedev-org"
github_oidc_repos = [
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
  owner       = "infrastructure-team"
  cost_center = "development"
}
