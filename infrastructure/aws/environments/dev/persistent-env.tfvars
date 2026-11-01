# Default values for dev environment
# These will be overridden by Atlantis command-line variables

pr_number = "8"
git_sha   = "f4b1452d69bf66be249ace4f694b70220ba2d6d1"

domain_name = "dev.gameplatform.click"
environment = "dev"
aws_region  = "us-east-1"

# Latest container images from ECR
container_images = {
  aes = "777777777771.dkr.ecr.us-east-1.amazonaws.com/gameplatform-aes:dev-1.1.7.5"
  ais = "777777777771.dkr.ecr.us-east-1.amazonaws.com/gameplatform-ais:dev-1.1.5.1"
  aps = "777777777771.dkr.ecr.us-east-1.amazonaws.com/gameplatform-aps:dev-1.0.1"
  afs = "777777777771.dkr.ecr.us-east-1.amazonaws.com/gameplatform-afs:dev-1.1.5.1"
  ahsat = "777777777771.dkr.ecr.us-east-1.amazonaws.com/gameplatform-ahsat:dev-1.1.5.4"
  lobby = "777777777771.dkr.ecr.us-east-1.amazonaws.com/gameplatform-lobby:dev-1.1.7.10"
  lobby_backend = "777777777771.dkr.ecr.us-east-1.amazonaws.com/gameplatform-lobby-backend:dev-1.1.7.9"
  nakama = "777777777771.dkr.ecr.us-east-1.amazonaws.com/gameplatform-nakama:dev-1.1.5.6"
}

# Service configuration
nakama_port        = 7350
lobby_port         = 3000
afs_port           = 9933
ahsat_port         = 6969
aes_port           = 1988
ais_port           = 5050
aps_port           = 4444
lobby_backend_port = 3001

# Resource allocation (small for testing)
cpu    = 512  # 0.5 vCPU
memory = 1024 # 1 GB

# Scaling
desired_count = 1

# Monitoring
log_retention_days = 3

# Health checks
health_check_path = {
  server        = "/"
  lobby         = "/"
  afs           = "/ping"
  ahsat         = "/ping"
  aes           = "/health"
  ais           = "/health"
  aps           = "/v0/aps/ping"
  lobby_backend = "/health"
}

# Database password for RDS connection
database_password = "7EbVA%Tc}O2*$Q_-Non7={Od$o(DlkM4"

# Additional tags
tags = {
  PRNumber    = "7"
  GitSHA      = "f4b1452d69bf66be249ace4f694b70220ba2d6d1"
  Environment = "dev"
  ManagedBy   = "atlantis"
  Purpose     = "pr-testing"
}

# ======================================================================
# SCHEDULER CONFIGURATION
# ======================================================================
# Automated shutdown/startup for cost optimization
# Shutdown: 20h BRT / 8 PM (Mon-Fri) = 23h UTC
# Startup:  06h BRT / 6 AM (Mon-Fri) = 09h UTC

enable_scheduler             = true # Set to true to enable scheduler
scheduler_enabled            = true  # Can be used to pause scheduling without destroying resources
scheduler_shutdown_cron      = "cron(0 23 ? * MON-FRI *)"
scheduler_startup_cron       = "cron(0 9 ? * MON-FRI *)"
scheduler_notification_email = "" # Optional: add email for notifications
