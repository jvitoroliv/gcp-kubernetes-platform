# -----------------------------------------------------------------------------
# STORAGE STACK - LEGACY
# Creates GCS bucket for Rogues assets
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "storage"
    managed_by  = "terraform"
  }, var.labels)
}

# -----------------------------------------------------------------------------
# GCS BUCKET
# -----------------------------------------------------------------------------

module "bucket" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-storage-bucket"

  name          = var.bucket_name
  location      = var.bucket_location
  project       = var.project_id
  storage_class = var.storage_class

  versioning_enabled          = var.versioning_enabled
  uniform_bucket_level_access = true

  lifecycle_rules = var.lifecycle_rules
  cors_config     = var.cors_config

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# BUCKET IAM BINDINGS
# -----------------------------------------------------------------------------

resource "google_storage_bucket_iam_member" "members" {
  for_each = { for idx, member in var.bucket_iam_members : idx => member }

  bucket = module.bucket.name
  role   = each.value.role
  member = each.value.member

  depends_on = [module.bucket]
}
