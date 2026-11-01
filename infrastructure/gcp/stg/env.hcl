# =============================================================================
# STG ENVIRONMENT CONFIGURATION
# =============================================================================
# Part of non-prod project (shared with dev)
# Region: us-east1 (cheaper than southamerica-east1)

locals {
  environment = "stg"
  project_id  = "project-nonprod-env"
  region      = "us-east1"
}
