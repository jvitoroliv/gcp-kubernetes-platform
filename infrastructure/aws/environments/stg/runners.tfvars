# ECS Shared Cluster (Runners) - Staging
region      = "us-east-1"
environment = "stg"

# Staging cluster configuration
enable_container_insights = true
capacity_providers        = ["FARGATE", "FARGATE_SPOT"]

# Capacity provider strategy for staging (balanced)
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

# Auto Scaling configuration for staging
enable_cluster_auto_scaling = true
target_capacity             = 70 # Target 70% utilization

# Service Connect configuration
enable_service_connect    = true
service_connect_namespace = "gameplatform-stg.local"

# Execute command configuration
enable_execute_command = true

additional_tags = {
  Owner              = "infrastructure-team"
  CostCenter         = "engineering"
  Environment        = "staging"
  Purpose            = "shared-cluster"
  MonitoringTier     = "high"
  DataClassification = "internal"
  Compliance         = "testing"
}
