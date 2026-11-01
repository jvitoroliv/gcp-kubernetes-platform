locals {
  # Stack identification
  stack_name = "postgres"

  # Common tags following FinOps standards
  common_tags = merge(var.tags, {
    environment       = var.environment
    terraform-managed = "true"
    project           = "project-live"
    stack             = local.stack_name
    cost-center       = "infrastructure"
    created-by        = "live"
  })

  # Database configuration
  db_password = random_password.postgres_password.result
}

# Generate random password for PostgreSQL
resource "random_password" "postgres_password" {
  length  = 32
  special = true
  upper   = true
  lower   = true
  numeric = true
  # Exclude characters not allowed in RDS passwords: / @ " (space)
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store password in SSM Parameter Store
resource "aws_ssm_parameter" "postgres_password" {
  name        = "/${var.environment}/${local.stack_name}/master-password"
  description = "Master password for ${var.environment} PostgreSQL RDS instance"
  type        = "SecureString"
  value       = local.db_password

  tags = merge(local.common_tags, {
    Name = "postgres-master-password"
  })
}

# Store connection details in SSM
resource "aws_ssm_parameter" "postgres_endpoint" {
  name        = "/${var.environment}/${local.stack_name}/endpoint"
  description = "Endpoint for ${var.environment} PostgreSQL RDS instance"
  type        = "String"
  value       = module.postgres_rds.endpoint

  tags = local.common_tags

  depends_on = [module.postgres_rds]
}

resource "aws_ssm_parameter" "postgres_connection_string" {
  name        = "/${var.environment}/${local.stack_name}/connection-string"
  description = "Connection string for ${var.environment} PostgreSQL RDS instance"
  type        = "SecureString"
  value       = "postgresql://${var.db_username}:${local.db_password}@${module.postgres_rds.endpoint}/${var.database_name}"

  tags = local.common_tags

  depends_on = [module.postgres_rds]
}

# IAM Role for RDS Enhanced Monitoring
module "rds_monitoring_role" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role"
  count  = var.monitoring_interval > 0 ? 1 : 0

  name        = "gameplatform-${var.environment}-rds-monitoring-role"
  description = "IAM role for RDS Enhanced Monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags)
}

# Attach AWS managed policy for RDS enhanced monitoring
module "rds_monitoring_policy_attachment" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment"
  count  = var.monitoring_interval > 0 ? 1 : 0

  role       = module.rds_monitoring_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Data sources for existing infrastructure
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_name}"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

data "aws_security_groups" "ecs" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*ecs*"]
  }
}

# PostgreSQL RDS Instance
module "postgres_rds" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/rds"

  # Basic configuration
  name_prefix = "${var.environment}-${local.stack_name}"
  environment = var.environment

  # Engine configuration
  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.instance_class

  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true

  # Database configuration
  database_name = var.database_name
  username      = var.db_username
  password      = local.db_password

  # Network configuration
  vpc_id                  = data.aws_vpc.main.id
  subnet_ids              = data.aws_subnets.private.ids
  allowed_security_groups = data.aws_security_groups.ecs.ids
  publicly_accessible     = false

  # Parameter group configuration - usando default por enquanto
  create_parameter_group = false

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window

  # Maintenance configuration
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Monitoring
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = var.monitoring_interval > 0 ? module.rds_monitoring_role[0].arn : null
  performance_insights_enabled = var.performance_insights_enabled

  # Security
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  tags = merge(
    local.common_tags,
    var.enable_scheduler ? {
      "scheduler:enabled"  = "true"
      "scheduler:resource" = "rds"
    } : {}
  )
}