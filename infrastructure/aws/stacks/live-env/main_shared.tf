# ======================================================================
# SHARED INFRASTRUCTURE COMPONENTS FOR PRODUCTION LIVE ENVIRONMENT
# ======================================================================

locals {
  common_tags = {
    Project         = "GamePlatform"
    Environment     = var.environment
    Component       = "live-env"
    ManagedBy       = "terraform"
    TerraformModule = "gameplatform-shared-infrastructure/live-env"
    ProductionEnv   = "true"
  }

  tags = merge(local.common_tags, var.additional_tags)
}

# Data sources for existing infrastructure
data "aws_caller_identity" "current" {}

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

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Type = "Public"
  }
}

data "aws_lb" "shared" {
  name = "gameplatform-${var.environment}-space-alb"
}

# data "aws_lb" "shared" {
#   name = "gameplatform-${var.environment}-shared-alb"
# }

data "aws_lb_listener" "shared_https" {
  load_balancer_arn = data.aws_lb.shared.arn
  port              = 443
}

data "aws_route53_zone" "main" {
  name = var.domain_name
}

data "aws_acm_certificate" "wildcard" {
  domain      = "*.${var.domain_name}"
  statuses    = ["ISSUED"]
  most_recent = true
}

# Production ECS Cluster - GamePlatform-live
module "ecs_cluster" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-cluster?ref=main"

  name = "gameplatform-${var.environment}"

  enable_container_insights          = var.enable_container_insights
  default_capacity_providers         = var.capacity_providers
  default_capacity_provider_strategy = var.capacity_provider_strategy

  tags = local.tags
}

# Service Discovery Namespace
module "service_discovery_namespace" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/service-discovery-namespace?ref=main"

  name        = "gameplatform-${var.environment}.local"
  description = "Service discovery namespace for GamePlatform ${var.environment} production environment"
  vpc_id      = data.aws_vpc.main.id

  tags = local.tags
}

# RDS Database connection (production database)
data "aws_db_instance" "shared_rds" {
  db_instance_identifier = "${var.environment}-postgres-postgres"
}

# Security Group for production services
module "security_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/security-group?ref=main"

  name        = "gameplatform-${var.environment}-sg"
  description = "Security group for ${var.environment} production live environment"
  vpc_id      = data.aws_vpc.main.id

  ingress_rules = [
    {
      from_port   = var.nakama_port
      to_port     = var.nakama_port
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
      description = "Server port from VPC"
    },
    {
      from_port   = var.lobby_port
      to_port     = var.lobby_port
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
      description = "Lobby port from VPC"
    },
    {
      from_port   = var.afs_port
      to_port     = var.afs_port
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
      description = "AFS port from VPC"
    },
    {
      from_port   = var.ahsat_port
      to_port     = var.ahsat_port
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
      description = "AHSAT port from VPC"
    },
    {
      from_port   = var.ais_port
      to_port     = var.ais_port
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
      description = "AIS port from VPC"
    },
    {
      from_port   = var.aps_port
      to_port     = var.aps_port
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
      description = "APS port from VPC"
    },
    {
      from_port   = var.aes_port
      to_port     = var.aes_port
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
      description = "AES port from VPC"
    },
    {
      from_port   = var.lobby_backend_port
      to_port     = var.lobby_backend_port
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
      description = "Lobby Backend port from VPC"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "All outbound traffic"
    }
  ]
}

# CloudWatch Log Groups for Production Services
module "server_log_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/ecs/gameplatform-${var.environment}-server"
  retention_in_days = var.log_retention_days
}

module "lobby_log_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/ecs/gameplatform-${var.environment}-lobby"
  retention_in_days = var.log_retention_days
}

module "afs_log_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/ecs/gameplatform-${var.environment}-afs"
  retention_in_days = var.log_retention_days
}

module "ahsat_log_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/ecs/gameplatform-${var.environment}-ahsat"
  retention_in_days = var.log_retention_days
}

module "aes_log_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/ecs/gameplatform-${var.environment}-aes"
  retention_in_days = var.log_retention_days
}

module "lobby_backend_log_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/ecs/gameplatform-${var.environment}-lobby-backend"
  retention_in_days = var.log_retention_days
}

# IAM Role for ECS Tasks
module "ecs_task_role" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role?ref=main"

  name = "gameplatform-${var.environment}-live-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role for ECS Task Execution
module "ecs_execution_role" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role?ref=main"

  name = "gameplatform-${var.environment}-live-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach execution role policy
module "ecs_execution_role_policy_attachment" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment?ref=main"

  role       = module.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# S3 access policy for task role (production-scoped)
module "s3_policy" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-policy?ref=main"

  name = "gameplatform-${var.environment}-live-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",
          "s3:CreateBucket",
          "s3:HeadBucket"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach S3 policy to task role
module "ecs_task_role_s3_policy_attachment" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment?ref=main"

  role       = module.ecs_task_role.name
  policy_arn = module.s3_policy.arn
}

# ECS Execute Command policy for task role
module "ecs_exec_policy" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-policy?ref=main"

  name = "gameplatform-${var.environment}-live-ecs-exec-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach ECS Exec policy to task role
module "ecs_task_role_exec_policy_attachment" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment?ref=main"

  role       = module.ecs_task_role.name
  policy_arn = module.ecs_exec_policy.arn
}