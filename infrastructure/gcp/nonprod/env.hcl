# =============================================================================
# NONPROD ENVIRONMENT CONFIGURATION
# =============================================================================
# Shared infrastructure for dev + stg environments
# Single VPC with multiple subnets for all nonprod clusters
# Region: us-east1

locals {
  environment = "nonprod"
  project_id  = "project-nonprod-env"
  region      = "us-east1"
}
