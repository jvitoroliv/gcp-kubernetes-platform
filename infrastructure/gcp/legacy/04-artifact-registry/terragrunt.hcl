# =============================================================================
# 04-ARTIFACT-REGISTRY STACK - LEGACY ENVIRONMENT
# =============================================================================
# Creates Artifact Registry for Rogues Docker images (migrated from ECR)

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks-legacy/04-artifact-registry"
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

  # Artifact Registry repository
  repository_id = "rogues-images"
  description   = "Docker images for Rogues services (migrated from AWS ECR)"
  format        = "DOCKER"

  # Grant pull access to service accounts
  repository_iam_members = [
    {
      role   = "roles/artifactregistry.reader"
      member = "serviceAccount:${dependency.foundation.outputs.service_account_emails["rogues-server"]}"
    },
    {
      role   = "roles/artifactregistry.reader"
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
