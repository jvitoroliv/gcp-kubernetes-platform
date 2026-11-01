# Production values for live environment
# domain_name = "gameplatform.example.com"
domain_name = "gameplatform.example.com"
environment = "live"
aws_region  = "sa-east-1"

# Production container images - will be updated by CI/CD
container_images = {
  aes           = "777777777772.dkr.ecr.sa-east-1.amazonaws.com/gameplatform-aes:live-4.0.4"
  afs           = "777777777772.dkr.ecr.sa-east-1.amazonaws.com/gameplatform-afs:live-4.0.4"
  ahsat         = "777777777772.dkr.ecr.sa-east-1.amazonaws.com/gameplatform-ahsat:live-4.0.4"
  lobby         = "777777777772.dkr.ecr.sa-east-1.amazonaws.com/gameplatform-lobby:live-4.0.5"
  lobby_backend = "777777777772.dkr.ecr.sa-east-1.amazonaws.com/gameplatform-lobby-backend:live-4.0.4"
  nakama        = "777777777772.dkr.ecr.sa-east-1.amazonaws.com/gameplatform-nakama:live-4.0.4"
}

# Service configuration
nakama_port        = 7350
lobby_port         = 3000
afs_port           = 9933
ahsat_port         = 6969
aes_port           = 1988
lobby_backend_port = 3001

# Production resource allocation
cpu    = 1024 # 2 vCPU
memory = 2048 # 4 GB

# Production resource allocation nakama
nakama_cpu    = 2048 # 2 vCPU
nakama_memory = 4096 # 4 GB

# Production scaling
desired_count = 1 # Multiple instances for high availability

# Production monitoring
log_retention_days = 30

# Health checks
health_check_path = {
  server        = "/"
  lobby         = "/"
  afs           = "/ping"
  ahsat         = "/ping"
  aes           = "/health"
  lobby_backend = "/health"
}

# Database password - should be updated with production credentials
database_password = "${DB_PASSWORD}"

# Production tags
tags = {
  Environment    = "live"
  ManagedBy      = "terraform"
  Purpose        = "production"
  CostCenter     = "engineering"
  Owner          = "devops"
  Backup         = "daily"
  MonitoringTier = "critical"
}

# Additional production tags
additional_tags = {
  DataClassification = "internal"
  Compliance         = "required"
  DisasterRecovery   = "tier1"
}

pr_number = 10

# Production cluster configuration
enable_container_insights = true
capacity_providers        = ["FARGATE", "FARGATE_SPOT"]

# Capacity provider strategy for production (prefer FARGATE for reliability)
capacity_provider_strategy = [
  {
    capacity_provider = "FARGATE"
    weight            = 100
    base              = 2 # Minimum 2 tasks on FARGATE
  },
  {
    capacity_provider = "FARGATE_SPOT"
    weight            = 0 # Disable SPOT for production critical workloads
  }
]
