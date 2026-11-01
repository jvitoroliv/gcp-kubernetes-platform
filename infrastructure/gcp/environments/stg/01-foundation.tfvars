# =============================================================================
# STG ENVIRONMENT - FOUNDATION STACK
# NOTE: Stg has SAME configuration as Prd for parity testing
# =============================================================================

project_id  = "project-nonprod-env"
environment = "stg"
region      = "us-east1"

# GCP APIs to enable
enable_apis = [
  "compute.googleapis.com",
  "container.googleapis.com",
  "sqladmin.googleapis.com",
  "servicenetworking.googleapis.com",
  "secretmanager.googleapis.com",
  "artifactregistry.googleapis.com",
  "dns.googleapis.com",
  "cloudresourcemanager.googleapis.com",
  "iam.googleapis.com",
  "logging.googleapis.com",
  "monitoring.googleapis.com",
  "certificatemanager.googleapis.com",
  "iap.googleapis.com",
  "redis.googleapis.com",
]

# Service accounts
create_gke_service_account      = true
create_cloudsql_service_account = true

# Workload identity service accounts for applications
create_workload_identity_service_accounts = {
  afs = {
    display_name = "AFS Service Account"
    roles = [
      "roles/secretmanager.secretAccessor",
      "roles/monitoring.metricWriter",
    ]
  }
  ahsat = {
    display_name = "AHSAT Service Account"
    roles = [
      "roles/secretmanager.secretAccessor",
      "roles/monitoring.metricWriter",
    ]
  }
  aes = {
    display_name = "AES Service Account"
    roles = [
      "roles/secretmanager.secretAccessor",
      "roles/monitoring.metricWriter",
    ]
  }
  ais = {
    display_name = "AIS Service Account"
    roles = [
      "roles/secretmanager.secretAccessor",
      "roles/monitoring.metricWriter",
    ]
  }
}

labels = {
  owner       = "infrastructure-team"
  cost_center = "stg"
}
