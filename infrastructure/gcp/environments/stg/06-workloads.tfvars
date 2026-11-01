# =============================================================================
# STG ENVIRONMENT - WORKLOADS STACK
# NOTE: Stg has SAME configuration as Prd for parity testing
# =============================================================================

project_id  = "project-nonprod-env"
environment = "stg"
region      = "us-east1"

# Artifact Registry - SAME AS PRD
artifact_registries = {
  gameplatform = {
    description            = "GamePlatform container images - stg"
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
  jwt-secret = {
    description = "JWT signing secret"
    replication = "automatic"
    labels = {
      type = "security"
    }
  }
  api-keys = {
    description = "API keys for external services"
    replication = "automatic"
    labels = {
      type = "security"
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
]

# Monitoring - SAME AS PRD
enable_alerting = true

notification_channels = {
  slack = {
    type         = "slack"
    display_name = "GamePlatform Staging Alerts"
    labels = {
      channel_name = "#project-nonprod-env-alerts"
    }
  }
  email = {
    type         = "email"
    display_name = "Infrastructure Team Email"
    labels = {
      email_address = "infra@gameplatform.example.com"
    }
  }
}

alert_policies = {
  high-cpu = {
    display_name          = "High CPU Usage"
    combiner              = "OR"
    notification_channels = ["slack", "email"]
    conditions = [
      {
        display_name = "GKE Node CPU > 80%"
        condition_threshold = {
          filter          = "resource.type = \"k8s_node\" AND metric.type = \"kubernetes.io/node/cpu/allocatable_utilization\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 0.8
          aggregations = [
            {
              alignment_period   = "60s"
              per_series_aligner = "ALIGN_MEAN"
            }
          ]
        }
      }
    ]
  }
  high-memory = {
    display_name          = "High Memory Usage"
    combiner              = "OR"
    notification_channels = ["slack", "email"]
    conditions = [
      {
        display_name = "GKE Node Memory > 80%"
        condition_threshold = {
          filter          = "resource.type = \"k8s_node\" AND metric.type = \"kubernetes.io/node/memory/allocatable_utilization\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 0.8
          aggregations = [
            {
              alignment_period   = "60s"
              per_series_aligner = "ALIGN_MEAN"
            }
          ]
        }
      }
    ]
  }
  database-connections = {
    display_name          = "Database Connection Issues"
    combiner              = "OR"
    notification_channels = ["slack", "email"]
    conditions = [
      {
        display_name = "Cloud SQL Connections > 400"
        condition_threshold = {
          filter          = "resource.type = \"cloudsql_database\" AND metric.type = \"cloudsql.googleapis.com/database/network/connections\""
          duration        = "300s"
          comparison      = "COMPARISON_GT"
          threshold_value = 400
          aggregations = [
            {
              alignment_period   = "60s"
              per_series_aligner = "ALIGN_MEAN"
            }
          ]
        }
      }
    ]
  }
}

labels = {
  owner       = "infrastructure-team"
  cost_center = "stg"
}
