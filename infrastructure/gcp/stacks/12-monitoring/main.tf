# -----------------------------------------------------------------------------
# MONITORING STACK
# This stack sets up infrastructure for the monitoring platform:
# - GCS bucket for Loki log storage
# - GCS bucket for Tempo trace storage
# - GCS bucket for Prometheus long-term storage
# - Service Accounts for Loki and Tempo with Workload Identity
# - IAM bindings for GCS access
# - Secret Manager secret for Grafana admin password
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "monitoring"
    managed_by  = "terraform"
  }, var.labels)

  # Naming convention
  name_prefix = "gameplatform-${var.environment}"
}

# -----------------------------------------------------------------------------
# GCS BUCKETS
# One bucket each for Loki, Tempo, and Prometheus long-term storage
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "loki" {
  name                        = "${local.name_prefix}-loki-logs"
  project                     = var.project_id
  location                    = var.gcs_location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = false
  }

  labels = merge(local.common_labels, {
    service = "loki"
  })
}

resource "google_storage_bucket" "tempo" {
  name                        = "${local.name_prefix}-tempo-traces"
  project                     = var.project_id
  location                    = var.gcs_location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = false
  }

  labels = merge(local.common_labels, {
    service = "tempo"
  })
}

resource "google_storage_bucket" "prometheus" {
  name                        = "${local.name_prefix}-prometheus-storage"
  project                     = var.project_id
  location                    = var.gcs_location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = false
  }

  labels = merge(local.common_labels, {
    service = "prometheus"
  })
}

# -----------------------------------------------------------------------------
# SERVICE ACCOUNTS
# Dedicated service accounts for Loki and Tempo to access their GCS buckets
# -----------------------------------------------------------------------------

resource "google_service_account" "loki" {
  account_id   = "${local.name_prefix}-loki"
  display_name = "Loki Log Storage"
  description  = "Service account for Loki to access GCS log storage bucket"
  project      = var.project_id
}

resource "google_service_account" "tempo" {
  account_id   = "${local.name_prefix}-tempo"
  display_name = "Tempo Trace Storage"
  description  = "Service account for Tempo to access GCS trace storage bucket"
  project      = var.project_id
}

# -----------------------------------------------------------------------------
# GCS IAM BINDINGS
# Grant objectAdmin on respective buckets to each service account
# -----------------------------------------------------------------------------

resource "google_storage_bucket_iam_binding" "loki_object_admin" {
  bucket = google_storage_bucket.loki.name
  role   = "roles/storage.objectAdmin"

  members = [
    "serviceAccount:${google_service_account.loki.email}",
  ]

  depends_on = [
    google_storage_bucket.loki,
    google_service_account.loki,
  ]
}

resource "google_storage_bucket_iam_binding" "tempo_object_admin" {
  bucket = google_storage_bucket.tempo.name
  role   = "roles/storage.objectAdmin"

  members = [
    "serviceAccount:${google_service_account.tempo.email}",
  ]

  depends_on = [
    google_storage_bucket.tempo,
    google_service_account.tempo,
  ]
}

resource "google_storage_bucket_iam_binding" "loki_legacy_bucket_reader" {
  bucket = google_storage_bucket.loki.name
  role   = "roles/storage.legacyBucketReader"

  members = [
    "serviceAccount:${google_service_account.loki.email}",
  ]

  depends_on = [
    google_storage_bucket.loki,
    google_service_account.loki,
  ]
}

resource "google_storage_bucket_iam_binding" "tempo_legacy_bucket_reader" {
  bucket = google_storage_bucket.tempo.name
  role   = "roles/storage.legacyBucketReader"

  members = [
    "serviceAccount:${google_service_account.tempo.email}",
  ]

  depends_on = [
    google_storage_bucket.tempo,
    google_service_account.tempo,
  ]
}

# -----------------------------------------------------------------------------
# WORKLOAD IDENTITY BINDINGS
# Allow Kubernetes service accounts to impersonate GCP service accounts
# -----------------------------------------------------------------------------

resource "google_service_account_iam_binding" "loki_workload_identity" {
  service_account_id = google_service_account.loki.id
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.loki_namespace}/loki]",
  ]

  depends_on = [google_service_account.loki]
}

resource "google_service_account_iam_binding" "tempo_workload_identity" {
  service_account_id = google_service_account.tempo.id
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.tempo_namespace}/tempo]",
  ]

  depends_on = [google_service_account.tempo]
}

# -----------------------------------------------------------------------------
# GRAFANA ADMIN PASSWORD
# Auto-generated password stored in Secret Manager
# -----------------------------------------------------------------------------

resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "google_secret_manager_secret" "grafana_admin_password" {
  secret_id = "${var.environment}-grafana-admin-password"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = merge(local.common_labels, {
    service = "grafana"
    type    = "password"
  })
}

resource "google_secret_manager_secret_version" "grafana_admin_password" {
  secret      = google_secret_manager_secret.grafana_admin_password.id
  secret_data = random_password.grafana_admin.result

  depends_on = [google_secret_manager_secret.grafana_admin_password]
}
