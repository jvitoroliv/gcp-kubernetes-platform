# =============================================================================
# 06-CLOUD-RUN STACK - LEGACY ENVIRONMENT
# =============================================================================
# Creates Cloud Run service for Rogues middleware (equivalent to ECS Fargate)

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks-legacy/06-cloud-run"
}

dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    service_account_emails = {
      rogues-middleware = "rogues-middleware@project-legacy-env.iam.gserviceaccount.com"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "artifact_registry" {
  config_path = "../04-artifact-registry"

  mock_outputs = {
    repository_url = "southamerica-east1-docker.pkg.dev/project-legacy-env/rogues-images"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Cloud Run service configuration
  service_name = "rogues-middleware"
  description  = "Rogues middleware service (migrated from ECS Fargate)"

  # Container configuration (equivalent to ECS: 1 vCPU, 2GB RAM)
  container = {
    name  = "middleware"
    image = "${dependency.artifact_registry.outputs.repository_url}/middleware-app:b333e32"
    port  = 3333
    env_vars = [
      { name = "NODE_ENV", value = "production" }
    ]
    resources = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }

  # Scaling configuration
  min_instance_count = 1
  max_instance_count = 10

  # Service account
  service_account = dependency.foundation.outputs.service_account_emails["rogues-middleware"]

  # Allow public access (like NLB)
  allow_unauthenticated = true

  labels = {
    environment = "legacy"
    project     = "gameplatform"
    service     = "rogues"
    component   = "middleware"
    managed_by  = "terragrunt"
  }
}
