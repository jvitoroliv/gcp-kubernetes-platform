# =============================================================================
# LEGACY ENVIRONMENT CONFIGURATION
# =============================================================================
# Region: southamerica-east1 (São Paulo) - same as PRD for Rogues migration
# This environment hosts legacy services migrated from AWS

locals {
  environment = "legacy"
  project_id  = "project-legacy-env"
  region      = "southamerica-east1"
}
