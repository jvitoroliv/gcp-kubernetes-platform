# =============================================================================
# 01-FOUNDATION STACK - DEV ENVIRONMENT
# =============================================================================

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/01-foundation"
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # GCP APIs to enable
  enable_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "dns.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "certificatemanager.googleapis.com",
    "iap.googleapis.com",
    "redis.googleapis.com",
  ]

  # Service accounts
  create_gke_service_account      = true
  create_cloudsql_service_account = true

  # Workload identity service accounts for applications
  create_workload_identity_service_accounts = {
    afs = {
      display_name = "AFS Service Account"
      roles = [
        "roles/secretmanager.secretAccessor",
        "roles/monitoring.metricWriter",
        "roles/storage.admin",
      ]
      workload_identity_binding = {
        namespace           = "gameplatform-dev"
        k8s_service_account = "game-platform-dev-afs"
      }
    }
    ahsat = {
      display_name = "AHSAT Service Account"
      roles = [
        "roles/secretmanager.secretAccessor",
        "roles/monitoring.metricWriter",
        "roles/storage.admin",
      ]
      workload_identity_binding = {
        namespace           = "gameplatform-dev"
        k8s_service_account = "game-platform-dev-ahsat"
      }
    }
    aes = {
      display_name = "AES Service Account"
      roles = [
        "roles/secretmanager.secretAccessor",
        "roles/monitoring.metricWriter",
        "roles/storage.admin",
      ]
      workload_identity_binding = {
        namespace           = "gameplatform-dev"
        k8s_service_account = "game-platform-dev-aes"
      }
    }
    ais = {
      display_name = "AIS Service Account"
      roles = [
        "roles/secretmanager.secretAccessor",
        "roles/monitoring.metricWriter",
        "roles/storage.admin",
        "roles/iam.serviceAccountTokenCreator",
      ]
      workload_identity_binding = {
        namespace           = "gameplatform-dev"
        k8s_service_account = "game-platform-dev-ais"
      }
    }
  }

  labels = {
    environment = "dev"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "development"
  }
}
