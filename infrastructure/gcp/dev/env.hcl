# =============================================================================
# DEV ENVIRONMENT CONFIGURATION
# =============================================================================
# Part of non-prod project (shared with stg)
# Region: us-east1 (cheaper than southamerica-east1)

locals {
  environment = "dev"
  project_id  = "project-nonprod-env"
  region      = "us-east1"
}
