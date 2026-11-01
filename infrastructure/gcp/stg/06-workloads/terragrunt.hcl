# =============================================================================
# 06-WORKLOADS STACK - STG ENVIRONMENT
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
    cluster_name     = "project-stg-workloads"
    cluster_endpoint = "https://172.16.0.2"
  }
}

dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    workload_identity_service_account_emails = {
      afs = "project-stg-afs@project-nonprod-env.iam.gserviceaccount.com"
      ais = "project-stg-ais@project-nonprod-env.iam.gserviceaccount.com"
    }
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Artifact Registry
  artifact_registries = {
    images = {
      description            = "GamePlatform container images - stg"
      format                 = "DOCKER"
      cleanup_policy_dry_run = false
      cleanup_policies = [
        {
          id     = "delete-untagged"
          action = "DELETE"
          condition = {
            tag_state  = "UNTAGGED"
            older_than = "604800s" # 7 days for stg
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
    github-arc-pat = {
      description = "GitHub PAT for Actions Runner Controller (ARC)"
      replication = "automatic"
      labels = {
        application = "arc"
        component   = "runners"
      }
    }
    gcs-access-key = {
      description = "GCS HMAC access key for S3-compatible API (AIS)"
      replication = "automatic"
      labels = {
        application = "ais"
        component   = "storage"
      }
    }
    gcs-secret-key = {
      description = "GCS HMAC secret key for S3-compatible API (AIS)"
      replication = "automatic"
      labels = {
        application = "ais"
        component   = "storage"
      }
    }
    afs-gcs-access-key = {
      description = "GCS HMAC access key for S3-compatible API (AFS)"
      replication = "automatic"
      labels = {
        application = "afs"
        component   = "storage"
      }
    }
    afs-gcs-secret-key = {
      description = "GCS HMAC secret key for S3-compatible API (AFS)"
      replication = "automatic"
      labels = {
        application = "afs"
        component   = "storage"
      }
    }
    hubspot-private-app-token = {
      description = "HubSpot private app token for analytics"
      replication = "automatic"
      labels = {
        application = "lobby-backend"
        component   = "analytics"
      }
    }
  }

  # External Secrets Operator - Service accounts for ESO in each cluster
  enable_external_secrets = true

  # Cert-Manager Service Account for DNS-01 challenge
  cert_manager_service_account = {
    enabled             = true
    name                = "project-stg-cert-manager"
    namespace           = "cert-manager"
    k8s_service_account = "cert-manager-stg"
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
  ]

  # Monitoring - Disabled for stg
  enable_alerting = false

  # GCS Storage Buckets
  storage_buckets = {
    "stg-gameplatform-server-software-stg" = {
      storage_class            = "STANDARD"
      versioning_enabled       = false
      public_access_prevention = "enforced"
      labels = {
        application = "afs-ais"
        purpose     = "asset-storage"
      }
      iam_members = [
        {
          role   = "roles/storage.objectAdmin"
          member = "serviceAccount:project-stg-afs@project-nonprod-env.iam.gserviceaccount.com"
        },
        {
          role   = "roles/storage.objectAdmin"
          member = "serviceAccount:project-stg-ais@project-nonprod-env.iam.gserviceaccount.com"
        }
      ]
    }
  }

  # HMAC Keys for GCS S3-compatible API
  hmac_keys = {
    afs = {
      service_account_email = "project-stg-afs@project-nonprod-env.iam.gserviceaccount.com"
      secret_access_key_id  = "afs-gcs-access-key"
      secret_secret_key_id  = "afs-gcs-secret-key"
    }
    ais = {
      service_account_email = "project-stg-ais@project-nonprod-env.iam.gserviceaccount.com"
      secret_access_key_id  = "gcs-access-key"
      secret_secret_key_id  = "gcs-secret-key"
    }
  }

  labels = {
    environment = "stg"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "staging"
  }
}
