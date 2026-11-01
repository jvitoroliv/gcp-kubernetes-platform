# =============================================================================
# 12-MONITORING STACK - DEV ENVIRONMENT
# =============================================================================

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/12-monitoring"
}

dependency "gke" {
  config_path = "../03-gke"

  mock_outputs = {
    cluster_name = "project-dev-workloads"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  gcs_location = "US-EAST1"
  cluster_name = dependency.gke.outputs.cluster_name

  loki_namespace  = "monitoring"
  tempo_namespace = "monitoring"

  labels = {
    environment = "dev"
    project     = "gameplatform"
    managed_by  = "terragrunt"
  }
}
