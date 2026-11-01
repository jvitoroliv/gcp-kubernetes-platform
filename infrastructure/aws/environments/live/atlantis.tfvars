# Production Environment Configuration - Atlantis
# Atlantis server for Terraform automation and CI/CD

region      = "sa-east-1"
environment = "live"
vpc_name    = "project-live-vpc"

# Atlantis Configuration
atlantis_image = "777777777772.dkr.ecr.sa-east-1.amazonaws.com/gameplatform-atlantis:v-1.0.0"
atlantis_port  = 4141

# Resource Configuration (production-grade)
atlantis_cpu    = 1024 # 1 vCPU
atlantis_memory = 2048 # 2 GB RAM

# Scaling Configuration - High availability
atlantis_desired_count = 1 # Multiple instances for HA
enable_auto_scaling    = true
min_capacity           = 0
max_capacity           = 4

# GitHub Configuration
github_owner = "example-gamedev-org"
github_repo  = "gameplatform-monorepo"

# Domain Configuration
atlantis_domain = "atlantis.live.gameplatform.click"

# Terraform Modules Repository
terraform_modules_repo = "github.com/example-gamedev-org/gameplatform-terraform.git"

# Logging Configuration
log_retention_days = 30 # Extended retention for production

# ALB Configuration
enable_access_logs = true
enable_waf         = true # Enable WAF protection for production

# Health Check Configuration
health_check_grace_period_seconds = 300
health_check_path                 = "/healthz"
health_check_interval             = 30
health_check_timeout              = 10
healthy_threshold_count           = 3
unhealthy_threshold_count         = 3

# Security Configuration
enable_container_insights = true
enable_execute_command    = false # Disable exec in production

# Secrets Configuration (will be provided during deployment)
# These will be prompted during terraform apply or set via environment variables:
# github_token = ""           # GitHub Personal Access Token
# github_webhook_secret = ""  # GitHub Webhook Secret

# Additional Tags
additional_tags = {
  Owner              = "infrastructure-team"
  CostCenter         = "production"
  Environment        = "live"
  Purpose            = "atlantis-server"
  MonitoringTier     = "critical"
  DataClassification = "internal"
  Compliance         = "required"
  DisasterRecovery   = "tier1"
  Backup             = "daily"
}