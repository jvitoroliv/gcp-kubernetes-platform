locals {
  common_tags = {
    Project         = "GamePlatform"
    Environment     = var.environment
    Component       = "Atlantis"
    ManagedBy       = "terraform"
    TerraformModule = "gameplatform-shared-infrastructure/atlantis"
  }

  tags = merge(local.common_tags, var.additional_tags)
}

# Data sources for existing shared infrastructure
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

# Get shared ALB
data "aws_lb" "shared" {
  name = "gameplatform-${var.environment}-shared-alb"
}

data "aws_lb_listener" "shared_https" {
  load_balancer_arn = data.aws_lb.shared.arn
  port              = 443
}

# Get Route53 hosted zone
data "aws_route53_zone" "main" {
  name = replace(var.atlantis_domain, "/^[^.]+\\./", "")
}

# Get ACM certificate
data "aws_acm_certificate" "wildcard" {
  domain      = "*.${data.aws_route53_zone.main.name}"
  statuses    = ["ISSUED"]
  most_recent = true
}

# ECS Cluster for Atlantis (reuse shared if exists, otherwise create)
data "aws_ecs_cluster" "shared" {
  cluster_name = "gameplatform-${var.environment}-shared-cluster"
}

data "aws_caller_identity" "current" {}

# CloudWatch Log Group for Atlantis
module "atlantis_logs" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group"

  name              = "/ecs/atlantis/${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(local.tags, {
    Purpose = "Atlantis-Logs"
  })
}

# SSM Parameters for sensitive data
module "github_token_parameter" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ssm-parameter"

  name        = "/atlantis/${var.environment}/github-token"
  description = "GitHub Personal Access Token for Atlantis"
  type        = "SecureString"
  value       = var.github_token

  tags = merge(local.tags, {
    Purpose = "Atlantis-Auth"
  })
}

module "github_webhook_secret_parameter" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ssm-parameter"

  name        = "/atlantis/${var.environment}/github-webhook-secret"
  description = "GitHub Webhook Secret for Atlantis"
  type        = "SecureString"
  value       = var.github_webhook_secret

  tags = merge(local.tags, {
    Purpose = "Atlantis-Webhook"
  })
}

# Duplicate parameters with env-var-friendly names for ECS secret injection
module "github_token_parameter_env" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ssm-parameter"

  name        = "/atlantis/${var.environment}/ATLANTIS_GH_TOKEN"
  description = "GitHub Token for Atlantis (env-compatible name)"
  type        = "SecureString"
  value       = var.github_token

  tags = merge(local.tags, { Purpose = "Atlantis-Auth" })
}

module "github_webhook_secret_parameter_env" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ssm-parameter"

  name        = "/atlantis/${var.environment}/ATLANTIS_GH_WEBHOOK_SECRET"
  description = "GitHub Webhook Secret for Atlantis (env-compatible name)"
  type        = "SecureString"
  value       = var.github_webhook_secret

  tags = merge(local.tags, { Purpose = "Atlantis-Webhook" })
}

# Security Group for Atlantis ECS tasks
module "atlantis_security_group" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/security-group"

  name        = "gameplatform-${var.environment}-atlantis-sg"
  description = "Security group for Atlantis ECS tasks"
  vpc_id      = data.aws_vpc.main.id

  ingress_rules = [
    {
      description = "Atlantis port from ALB"
      from_port   = var.atlantis_port
      to_port     = var.atlantis_port
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
    }
  ]

  egress_rules = [
    {
      description = "All outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  tags = merge(local.tags, {
    Purpose = "Atlantis-Security"
  })
}

# IAM Role for ECS Task Execution (pull images, logs)
module "atlantis_execution_role" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role"

  name = "gameplatform-${var.environment}-atlantis-execution-role"
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

  tags = local.tags
}

# IAM Role for Atlantis Task (application permissions)
module "atlantis_task_role" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role"

  name = "gameplatform-${var.environment}-atlantis-task-role"
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

  tags = local.tags
}

# ECS Task Execution Role Policy Attachment
module "atlantis_execution_policy" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment"

  role       = module.atlantis_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Extra permissions for Execution Role to read SSM parameters used as container secrets
module "atlantis_execution_ssm_policy" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-policy"

  name = "gameplatform-${var.environment}-atlantis-exec-ssm"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/atlantis/${var.environment}/*"
        ]
      }
    ]
  })
}

module "atlantis_execution_ssm_attach" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment"

  role       = module.atlantis_execution_role.name
  policy_arn = module.atlantis_execution_ssm_policy.arn
}

# Custom policy for Atlantis task (Terraform operations)
# module "atlantis_task_policy" {
#   source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-policy"

#   name = "gameplatform-${var.environment}-atlantis-task-policy"
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           # S3 access for Terraform state
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:DeleteObject",
#           "s3:ListBucket"
#         ]
#         Resource = [
#           "arn:aws:s3:::gameplatform-us-east-1-tfstate",
#           "arn:aws:s3:::gameplatform-us-east-1-tfstate/*"
#         ]
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           # DynamoDB for state locking
#           "dynamodb:GetItem",
#           "dynamodb:PutItem",
#           "dynamodb:DeleteItem"
#         ]
#         Resource = "arn:aws:dynamodb:us-east-1:777777777771:table/gameplatform-us-east-1-tf-locks"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           # SSM access for reading secrets
#           "ssm:GetParameter",
#           "ssm:GetParameters",
#           "ssm:GetParametersByPath"
#         ]
#         Resource = [
#           "arn:aws:ssm:*:*:parameter/atlantis/${var.environment}/*"
#         ]
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           # Full access for managing infrastructure (admin for Atlantis)
#           "*"
#         ]
#         Resource = "*"
#         Condition = {
#           StringEquals = {
#             "aws:RequestedRegion" = var.region
#           }
#         }
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           # Route53 is global service (no region restriction)
#           "route53:*"
#         ]
#         Resource = "*"
#       }
#     ]
#   })

#   tags = local.tags
# }

module "atlantis_task_policy" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-policy"

  name = "gameplatform-${var.environment}-atlantis-task-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "*"
        ]
        Resource = [
          "*"
        ]
      }
    ]
  })

  tags = local.tags
}

# Attach custom policy to task role
module "atlantis_task_policy_attachment" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment"

  role       = module.atlantis_task_role.name
  policy_arn = module.atlantis_task_policy.arn
}

# ALB Target Group for Atlantis
module "atlantis_target_group" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-target-group"

  name        = "gameplatform-${var.environment}-atlantis-tg"
  port        = var.atlantis_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
  target_type = "ip"

  health_check = {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/healthz"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(local.tags, {
    Purpose = "Atlantis-ALB-Target"
  })
}

# ALB Listener Rule for Atlantis
module "atlantis_listener_rule" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener-rule"

  listener_arn = data.aws_lb_listener.shared_https.arn
  priority     = 100 # High priority for Atlantis

  condition = {
    host_header = {
      values = [var.atlantis_domain]
    }
  }

  action = {
    type             = "forward"
    target_group_arn = module.atlantis_target_group.arn
  }

  tags = local.tags
}

# Route53 Record for Atlantis
module "atlantis_dns_record" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-record"

  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.atlantis_domain
  type    = "A"

  alias = {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = true
  }
}

# ECS Task Definition for Atlantis
module "atlantis_task_definition" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-task-definition"

  family                   = "gameplatform-${var.environment}-atlantis"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.atlantis_cpu
  memory                   = var.atlantis_memory
  execution_role_arn       = module.atlantis_execution_role.arn
  task_role_arn            = module.atlantis_task_role.arn

  container = {
    name      = "atlantis"
    image     = var.atlantis_image
    essential = true

    port_mappings = [
      {
        container_port = var.atlantis_port
        host_port      = var.atlantis_port
        protocol       = "tcp"
      }
    ]

    log_group_name = module.atlantis_logs.name

    environment = {
      # Atlantis basic configuration
      ATLANTIS_PORT         = tostring(var.atlantis_port)
      ATLANTIS_ATLANTIS_URL = "https://${var.atlantis_domain}"
      # Limit allowlist to the org to ensure PRs/comments are processed
      ATLANTIS_REPO_ALLOWLIST          = "github.com/${var.github_owner}/*"
      ATLANTIS_HIDE_PREV_PLAN_COMMENTS = "true"
      ATLANTIS_WRITE_GIT_CREDS         = "true"
      ATLANTIS_DISABLE_APPLY_ALL       = "true"
      ATLANTIS_DISABLE_AUTOPLAN        = "false"
      ATLANTIS_PARALLEL_POOL_SIZE      = "10"
      # Temporarily increase log level to aid webhook debugging
      ATLANTIS_LOG_LEVEL = "debug"

      # GitHub configuration (user via plain env; token/secret via ECS secrets)
      ATLANTIS_GH_USER = var.github_owner

      # AWS configuration
      AWS_REGION         = var.region
      AWS_DEFAULT_REGION = var.region

      # This is a default configuration that applies to all repositories.
      ATLANTIS_REPO_CONFIG_JSON = jsonencode({ repos = [{ id = "/.*/", allowed_overrides = ["workflow", "apply_requirements"], allow_custom_workflows = true }] })

    }

    # No explicit flags (older Atlantis builds may not support terraform flags). Rely on env vars above.

    ssm_secret_paths = [
      "/atlantis/${var.environment}/ATLANTIS_GH_WEBHOOK_SECRET",
      "/atlantis/${var.environment}/ATLANTIS_GH_TOKEN"
    ]
  }

  tags = local.tags
}

# ECS Service for Atlantis
module "atlantis_service" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/ecs-service"

  name            = "gameplatform-${var.environment}-atlantis"
  cluster_arn     = data.aws_ecs_cluster.shared.arn
  task_definition = module.atlantis_task_definition.arn
  desired_count   = var.atlantis_desired_count
  launch_type     = "FARGATE"

  network_configuration = {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [module.atlantis_security_group.id]
    assign_public_ip = false
  }

  load_balancer = {
    target_group_arn = module.atlantis_target_group.arn
    container_name   = "atlantis"
    container_port   = var.atlantis_port
  }

  depends_on = [module.atlantis_listener_rule]

  tags = local.tags
}

# Auto Scaling Target (if enabled)
resource "aws_appautoscaling_target" "atlantis" {
  count = var.enable_auto_scaling ? 1 : 0

  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${data.aws_ecs_cluster.shared.cluster_name}/${module.atlantis_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = local.tags
}

# Auto Scaling Policy - Scale Up
resource "aws_appautoscaling_policy" "atlantis_scale_up" {
  count = var.enable_auto_scaling ? 1 : 0

  name               = "gameplatform-${var.environment}-atlantis-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.atlantis[0].resource_id
  scalable_dimension = aws_appautoscaling_target.atlantis[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.atlantis[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_out_cooldown = 300
    scale_in_cooldown  = 300
  }
}
