# -----------------------------------------------------------------------------
# ARTIFACT REGISTRY STACK - LEGACY
# Creates Docker registry for Rogues images
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "artifact-registry"
    managed_by  = "terraform"
  }, var.labels)
}

# -----------------------------------------------------------------------------
# ARTIFACT REGISTRY REPOSITORY
# -----------------------------------------------------------------------------

module "repository" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/artifact-registry-repository"

  repository_id = var.repository_id
  location      = var.region
  project       = var.project_id
  format        = var.format
  description   = var.description

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# REPOSITORY IAM BINDINGS
# -----------------------------------------------------------------------------

resource "google_artifact_registry_repository_iam_member" "members" {
  for_each = { for idx, member in var.repository_iam_members : idx => member }

  project    = var.project_id
  location   = var.region
  repository = module.repository.name
  role       = each.value.role
  member     = each.value.member

  depends_on = [module.repository]
}
