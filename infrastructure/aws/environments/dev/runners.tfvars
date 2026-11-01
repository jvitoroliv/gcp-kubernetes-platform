# ECS Shared Cluster (Runners) - dev
region      = "us-east-1"
environment = "dev"

enable_container_insights  = true
capacity_providers         = ["FARGATE", "FARGATE_SPOT"]
capacity_provider_strategy = []

additional_tags = {
  Owner       = "infrastructure-team"
  CostCenter  = "development"
  Environment = "dev"
  Purpose     = "shared-cluster"
}

