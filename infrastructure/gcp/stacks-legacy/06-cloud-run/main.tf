# -----------------------------------------------------------------------------
# CLOUD RUN STACK - LEGACY
# Creates Cloud Run service for Rogues middleware
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "cloud-run"
    managed_by  = "terraform"
  }, var.labels)
}

# -----------------------------------------------------------------------------
# CLOUD RUN SERVICE
# -----------------------------------------------------------------------------

module "cloud_run" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-run-service"

  name        = var.service_name
  location    = var.region
  project     = var.project_id
  description = var.description

  container = var.container

  min_instance_count = var.min_instance_count
  max_instance_count = var.max_instance_count

  service_account = var.service_account

  allow_unauthenticated = var.allow_unauthenticated

  labels = local.common_labels
}
