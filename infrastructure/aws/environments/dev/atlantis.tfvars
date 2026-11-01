# Development Environment Configuration - Atlantis
# Atlantis server for Terraform automation and CI/CD

region      = "us-east-1"
environment = "dev"

# Atlantis Configuration
atlantis_image = "777777777771.dkr.ecr.us-east-1.amazonaws.com/gameplatform-atlantis:tf-v1.13.1"
atlantis_port  = 4141

# Resource Configuration (cost-optimized for dev)
atlantis_cpu    = 1024 # 1 vCPU
atlantis_memory = 2048 # 2 GB RAM

# Scaling Configuration
atlantis_desired_count = 1
enable_auto_scaling    = true
min_capacity           = 1
max_capacity           = 2 # Limited scaling for dev

# GitHub Configuration
github_owner = "example-gamedev-org" # Replace with your GitHub org/user
github_repo  = "gameplatform-monorepo"

# Domain Configuration
atlantis_domain = "atlantis.dev.gameplatform.click"

# Terraform Modules Repository
terraform_modules_repo = "github.com/example-gamedev-org/gameplatform-terraform.git"

# Logging Configuration
log_retention_days = 3 # 3 days retention for dev

# ALB Access Logs
enable_access_logs = true

# Secrets Configuration (will be provided during deployment)
# These will be prompted during terraform apply or set via environment variables:
# github_token = ""           # GitHub Personal Access Token
# github_webhook_secret = ""  # GitHub Webhook Secret

# Additional Tags
additional_tags = {
  Owner       = "infrastructure-team"
  CostCenter  = "development"
  Environment = "dev"
  Purpose     = "atlantis-server"
  Backup      = "none"
}
