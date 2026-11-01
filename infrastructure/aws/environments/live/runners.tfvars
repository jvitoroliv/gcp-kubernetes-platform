# ECS Shared Cluster (Runners) - Production
region      = "sa-east-1"
environment = "live"

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

# Auto Scaling configuration for production
enable_cluster_auto_scaling = true
target_capacity             = 80 # Target 80% utilization

# Service Connect configuration
enable_service_connect    = true
service_connect_namespace = "project-live.local"

# Execute command configuration
enable_execute_command = true

additional_tags = {
  Owner              = "infrastructure-team"
  CostCenter         = "production"
  Environment        = "live"
  Purpose            = "shared-cluster"
  MonitoringTier     = "critical"
  DataClassification = "internal"
  Compliance         = "required"
  DisasterRecovery   = "tier1"
  Backup             = "daily"
}