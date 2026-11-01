# GCS bucket for ephemeral environment database dumps
# Weekly dumps from DEV are stored here and used to initialize ephemeral PostgreSQL pods

resource "google_storage_bucket" "ephemeral_db_dumps" {
  name          = "gameplatform-ephemeral-db-dumps"
  project       = var.project_id
  location      = "US-EAST1"
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30 # Delete dumps older than 30 days
    }
    action {
      type = "Delete"
    }
  }

  labels = merge(local.common_labels, {
    purpose = "ephemeral-environments"
  })
}

# Allow GitHub Actions SA to write dumps
resource "google_storage_bucket_iam_member" "ephemeral_db_dumps_writer" {
  count  = var.enable_github_oidc ? 1 : 0
  bucket = google_storage_bucket.ephemeral_db_dumps.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.github_actions_service_account[0].email}"
}

# Allow ephemeral workloads (via DEV AIS SA) to read dumps
resource "google_storage_bucket_iam_member" "ephemeral_db_dumps_reader" {
  bucket = google_storage_bucket.ephemeral_db_dumps.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:project-dev-ais@project-nonprod-env.iam.gserviceaccount.com"
}

output "ephemeral_db_dumps_bucket" {
  description = "GCS bucket for ephemeral environment database dumps"
  value       = google_storage_bucket.ephemeral_db_dumps.name
}
