# =============================================================================
# 01-FOUNDATION STACK - LEGACY ENVIRONMENT
# =============================================================================
# Enables required APIs and creates base service accounts for Rogues migration

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks-legacy/01-foundation"
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # GCP APIs to enable for Rogues
  enable_apis = [
    "compute.googleapis.com",
    "run.googleapis.com",
    "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "dns.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "certificatemanager.googleapis.com",
  ]

  # Service accounts for Rogues
  service_accounts = {
    rogues-server = {
      display_name = "Rogues Server Service Account"
      description  = "Service account for Rogues game server VM"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/storage.objectViewer",
        "roles/secretmanager.secretAccessor",
      ]
    }
    rogues-middleware = {
      display_name = "Rogues Middleware Service Account"
      description  = "Service account for Rogues middleware Cloud Run"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/storage.objectViewer",
        "roles/secretmanager.secretAccessor",
      ]
    }
  }

  labels = {
    environment = "legacy"
    project     = "gameplatform"
    service     = "rogues"
    managed_by  = "terragrunt"
  }

  # GitHub Actions OIDC for CI/CD pipelines
  enable_github_oidc = true
  github_org         = "example-gamedev-org"
  github_oidc_repos = [
    "gameplatform-shared-infrastructure-gcp",
    "gameplatform-monorepo",
  ]
}
