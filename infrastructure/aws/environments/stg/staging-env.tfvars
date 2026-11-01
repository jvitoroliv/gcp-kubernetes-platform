# Staging values for staging environment
domain_name = "stg.gameplatform.click"
environment = "stg"
aws_region  = "us-east-1"

# Staging container images - will be updated by CI/CD
container_images = {
  aes = "777777777775.dkr.ecr.us-east-1.amazonaws.com/gameplatform-aes:stg-1.1.5.0.1"
  ais = "777777777775.dkr.ecr.us-east-1.amazonaws.com/gameplatform-ais:stg-1.1.4.8.5"
  aps = "777777777775.dkr.ecr.us-east-1.amazonaws.com/gameplatform-aps:dev-1.0.0"
  afs = "777777777775.dkr.ecr.us-east-1.amazonaws.com/gameplatform-afs:stg-1.1.5.0.1"
  ahsat = "777777777775.dkr.ecr.us-east-1.amazonaws.com/gameplatform-ahsat:stg-1.1.5.0.1"
  lobby = "777777777775.dkr.ecr.us-east-1.amazonaws.com/gameplatform-lobby:stg-1.1.7.2"
  lobby_backend = "777777777775.dkr.ecr.us-east-1.amazonaws.com/gameplatform-lobby-backend:stg-1.1.7"
  nakama = "777777777775.dkr.ecr.us-east-1.amazonaws.com/gameplatform-nakama:stg-1.1.5.0.1"
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

# Staging resource allocation (same as production for realistic testing)
cpu    = 1024 # 1 vCPU
memory = 2048 # 2 GB

# Staging resource allocation nakama
nakama_cpu    = 2048 # 2 vCPU
nakama_memory = 4096 # 4 GB

# Staging scaling
desired_count = 1

# Staging monitoring
log_retention_days = 14

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

# Database password - should be updated with staging credentials
database_password = "${DB_PASSWORD}"

# Staging tags
tags = {
  Environment    = "staging"
  ManagedBy      = "terraform"
  Purpose        = "pre-production-testing"
  CostCenter     = "engineering"
  Owner          = "devops"
  Backup         = "weekly"
  MonitoringTier = "high"
}

# Additional staging tags
additional_tags = {
  DataClassification = "internal"
  Compliance         = "testing"
  DisasterRecovery   = "tier2"
}

pr_number = 20

# Staging cluster configuration
enable_container_insights = true
capacity_providers        = ["FARGATE", "FARGATE_SPOT"]

# Capacity provider strategy for staging (balanced approach)
capacity_provider_strategy = [
  {
    capacity_provider = "FARGATE"
    weight            = 80
    base              = 1 # Minimum 1 task on FARGATE
  },
  {
    capacity_provider = "FARGATE_SPOT"
    weight            = 20 # Some SPOT for cost optimization
  }
]

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
