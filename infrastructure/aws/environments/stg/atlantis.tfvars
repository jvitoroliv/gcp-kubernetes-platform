# Staging Environment Configuration - Atlantis
# Atlantis server for Terraform automation and CI/CD

region      = "us-east-1"
environment = "stg"
vpc_name    = "project-stg-vpc"

# Atlantis Configuration
atlantis_image = "777777777775.dkr.ecr.us-east-1.amazonaws.com/gameplatform-atlantis:v-1.0.0"
atlantis_port  = 4141

# Resource Configuration (staging)
atlantis_cpu    = 512  # 0.5 vCPU
atlantis_memory = 1024 # 1 GB RAM

# Scaling Configuration
atlantis_desired_count = 1
enable_auto_scaling    = false
min_capacity           = 0
max_capacity           = 2

# GitHub Configuration
github_owner = "example-gamedev-org"
github_repo  = "gameplatform-monorepo"

# Domain Configuration
atlantis_domain = "atlantis.stg.gameplatform.click"

# Terraform Modules Repository
terraform_modules_repo = "github.com/example-gamedev-org/gameplatform-terraform.git"

# Logging Configuration
log_retention_days = 14 # Moderate retention for staging

# ALB Configuration
enable_access_logs = true
enable_waf         = false # Disabled for cost savings in staging

# Health Check Configuration
health_check_grace_period_seconds = 180
health_check_path                 = "/healthz"
health_check_interval             = 30
health_check_timeout              = 10
healthy_threshold_count           = 2
unhealthy_threshold_count         = 3

# Security Configuration
enable_container_insights = true
enable_execute_command    = true # Enabled for debugging in staging

# Secrets Configuration (will be provided during deployment)
# These will be prompted during terraform apply or set via environment variables:
# github_token = ""           # GitHub Personal Access Token
# github_webhook_secret = ""  # GitHub Webhook Secret

# Additional Tags
additional_tags = {
  Owner              = "infrastructure-team"
  CostCenter         = "engineering"
  Environment        = "staging"
  Purpose            = "atlantis-server"
  MonitoringTier     = "high"
  DataClassification = "internal"
  Compliance         = "testing"
}
