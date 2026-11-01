# Production values for Metabase autoscaling infrastructure
environment = "live"
region      = "sa-east-1"
domain_name = "gameplatform.example.com"

# EC2 Configuration
ami_id        = "ami-035efd31ab8835d8a" # Ubuntu 24.04 LTS sa-east-1
instance_type = "t2.medium"

# Auto Scaling Configuration
min_size         = 1
max_size         = 1
desired_capacity = 1

# Metabase Configuration
metabase_port = 3000

# Database Configuration (will use output from metabase-db stack)
database_endpoint = "" # Will be set from metabase-db output
database_name     = "metabase"
database_username = "metabase"
database_password = "" # Will be retrieved from Secrets Manager

# ALB Configuration
listener_rule_priority = 200

# Storage Configuration
root_volume_size = 30

# Monitoring
log_retention_days = 7

# Production Tags
additional_tags = {
  dataclassification = "internal"
  compliance         = "required"
  disasterrecovery   = "tier2"
  costcenter         = "engineering"
  owner              = "devops"
  backup             = "daily"
  monitoringtier     = "standard"
}