# ======================================================================
# METABASE DATABASE INFRASTRUCTURE FOR PRODUCTION LIVE ENVIRONMENT
# ======================================================================

locals {
  common_tags = {
    Project         = "GamePlatform"
    Environment     = var.environment
    Component       = "metabase-db"
    ManagedBy       = "terraform"
    TerraformModule = "gameplatform-shared-infrastructure/metabase-db"
    ProductionEnv   = "true"
  }

  tags = merge(local.common_tags, var.additional_tags)
}

# Data sources for existing infrastructure
data "aws_vpc" "main" {
  tags = {
    Name = "gameplatform-${var.environment}-vpc"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Type = "Private"
  }
}

# Get existing RDS security group to reuse same configuration
data "aws_security_group" "rds" {
  tags = {
    Name = "${var.rds-security-group-name}"
  }
}

# Random password for database if not provided
resource "random_password" "db_password" {
  count   = var.database_password == "" ? 1 : 0
  length  = 32
  special = true
}

locals {
  db_password = var.database_password != "" ? var.database_password : random_password.db_password[0].result
}

# Store password in Secrets Manager
module "db_password_secret" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/secretsmanager-secret?ref=main"

  name        = "gameplatform-${var.environment}-metabase-db-password"
  description = "Password for Metabase RDS Aurora Serverless database"

  secret_string = jsonencode({
    username = var.master_username
    password = local.db_password
    engine   = "aurora-postgresql"
    host     = module.metabase_serverless_db.cluster_endpoint
    port     = module.metabase_serverless_db.cluster_port
    dbname   = var.database_name
  })

  tags = local.tags
}

# Aurora Serverless v2 PostgreSQL Database
module "metabase_serverless_db" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/rds-serverless?ref=main"

  cluster_identifier = "gameplatform-${var.environment}-metabase-serverless"
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  database_name      = var.database_name
  master_username    = var.master_username
  master_password    = local.db_password

  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [data.aws_security_group.rds.id]

  serverless_min_capacity = var.serverless_min_capacity
  serverless_max_capacity = var.serverless_max_capacity

  instance_count = var.instance_count

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  skip_final_snapshot             = var.skip_final_snapshot
  enabled_cloudwatch_logs_exports = ["postgresql"]
  storage_encrypted               = true

  deletion_protection         = var.deletion_protection
  apply_immediately           = var.apply_immediately
  allow_major_version_upgrade = var.allow_major_version_upgrade

  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval          = var.monitoring_interval

  tags = local.tags
}

# CloudWatch Log Group for RDS
module "rds_log_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/aws/rds/cluster/gameplatform-${var.environment}-metabase-serverless/postgresql"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

# CloudWatch Alarms for RDS
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "gameplatform-${var.environment}-metabase-db-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "This metric monitors database CPU utilization"

  dimensions = {
    DBClusterIdentifier = module.metabase_serverless_db.cluster_id
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "gameplatform-${var.environment}-metabase-db-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.connections_alarm_threshold
  alarm_description   = "This metric monitors database connections"

  dimensions = {
    DBClusterIdentifier = module.metabase_serverless_db.cluster_id
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "serverless_capacity" {
  alarm_name          = "gameplatform-${var.environment}-metabase-db-serverless-capacity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ServerlessDatabaseCapacity"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.capacity_alarm_threshold
  alarm_description   = "This metric monitors Aurora Serverless capacity units"

  dimensions = {
    DBClusterIdentifier = module.metabase_serverless_db.cluster_id
  }

  tags = local.tags
}