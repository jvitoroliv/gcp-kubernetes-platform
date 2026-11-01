# =============================================================================
# 03-STORAGE STACK - LEGACY ENVIRONMENT
# =============================================================================
# Creates GCS bucket for Rogues assets (migrated from S3)

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks-legacy/03-storage"
}

dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    service_account_emails = {
      rogues-server     = "rogues-server@project-legacy-env.iam.gserviceaccount.com"
      rogues-middleware = "rogues-middleware@project-legacy-env.iam.gserviceaccount.com"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # GCS bucket for Rogues assets (equivalent to rogues-gameplatform-server-software-rogues S3 bucket)
  bucket_name     = "rogues-gameplatform-server-software"
  bucket_location = include.env.locals.region
  storage_class   = "STANDARD"

  # Enable versioning for asset safety
  versioning_enabled = true

  # CORS configuration for web access
  cors_config = {
    origin          = ["*"]
    method          = ["GET", "HEAD", "OPTIONS"]
    response_header = ["Content-Type", "Content-Length", "Content-Range"]
    max_age_seconds = 3600
  }

  # Lifecycle rules
  lifecycle_rules = [
    {
      action = {
        type = "Delete"
      }
      condition = {
        num_newer_versions = 3
      }
    }
  ]

  # Grant access to service accounts
  bucket_iam_members = [
    {
      role   = "roles/storage.objectViewer"
      member = "serviceAccount:${dependency.foundation.outputs.service_account_emails["rogues-server"]}"
    },
    {
      role   = "roles/storage.objectViewer"
      member = "serviceAccount:${dependency.foundation.outputs.service_account_emails["rogues-middleware"]}"
    }
  ]

  labels = {
    environment = "legacy"
    project     = "gameplatform"
    service     = "rogues"
    managed_by  = "terragrunt"
  }
}
