# -----------------------------------------------------------------------------
# GCS BUCKET OUTPUTS
# -----------------------------------------------------------------------------

output "loki_bucket_name" {
  description = "GCS bucket name for Loki log storage"
  value       = google_storage_bucket.loki.name
}

output "tempo_bucket_name" {
  description = "GCS bucket name for Tempo trace storage"
  value       = google_storage_bucket.tempo.name
}

output "prometheus_bucket_name" {
  description = "GCS bucket name for Prometheus long-term storage"
  value       = google_storage_bucket.prometheus.name
}

# -----------------------------------------------------------------------------
# SERVICE ACCOUNT OUTPUTS
# -----------------------------------------------------------------------------

output "loki_service_account_email" {
  description = "Email of the Loki GCP service account"
  value       = google_service_account.loki.email
}

output "tempo_service_account_email" {
  description = "Email of the Tempo GCP service account"
  value       = google_service_account.tempo.email
}

# -----------------------------------------------------------------------------
# SECRET MANAGER OUTPUTS
# -----------------------------------------------------------------------------

output "grafana_admin_password_secret_id" {
  description = "Secret Manager secret ID for the Grafana admin password"
  value       = google_secret_manager_secret.grafana_admin_password.secret_id
}
