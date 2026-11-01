# =============================================================================
# PRODUCTION ENVIRONMENT CONFIGURATION
# =============================================================================
# Region: southamerica-east1 (São Paulo) for low latency to Brazilian users
# Only production uses this region

locals {
  environment = "prd"
  project_id  = "project-prd-env"
  region      = "southamerica-east1"
}
