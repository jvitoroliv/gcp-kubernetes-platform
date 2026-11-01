# ======================================================================
# METABASE INFRASTRUCTURE FOR PRODUCTION LIVE ENVIRONMENT
# ======================================================================

locals {
  common_tags = {
    Project         = "GamePlatform"
    Environment     = var.environment
    Component       = "metabase"
    ManagedBy       = "terraform"
    TerraformModule = "gameplatform-shared-infrastructure/metabase"
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

data "aws_lb" "shared" {
  name = "gameplatform-${var.environment}-space-alb"
}

data "aws_lb_listener" "shared_https" {
  load_balancer_arn = data.aws_lb.shared.arn
  port              = 443
}

data "aws_route53_zone" "main" {
  name = var.domain_name
}

# Get existing RDS security group to allow database access
data "aws_security_group" "rds" {
  tags = {
    Name = "golden-gate-${var.environment}"
  }
}

# Security Group for Metabase instances
module "metabase_security_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/security-group?ref=main"

  name        = "gameplatform-${var.environment}-metabase-sg"
  description = "Security group for Metabase instances"
  vpc_id      = data.aws_vpc.main.id

  ingress_rules = [
    {
      from_port   = var.metabase_port
      to_port     = var.metabase_port
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
      description = "Metabase port from VPC"
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

  tags = local.tags
}

# IAM Role for EC2 instances
module "metabase_instance_role" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role?ref=main"

  name = "gameplatform-${var.environment}-metabase-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# IAM Policy for EC2 instances
module "metabase_instance_policy" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-policy?ref=main"

  name = "gameplatform-${var.environment}-metabase-instance-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:sa-east-1:777777777772:secret:project-live-metabase-db-password-*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeAssociation",
          "ssm:GetDeployablePatchSnapshotForInstance",
          "ssm:GetDocument",
          "ssm:DescribeDocument",
          "ssm:GetManifest",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:PutInventory",
          "ssm:PutComplianceItems",
          "ssm:PutConfigurePackageResult",
          "ssm:UpdateAssociationStatus",
          "ssm:UpdateInstanceAssociationStatus",
          "ssm:UpdateInstanceInformation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

# Attach policy to role
module "metabase_instance_role_policy_attachment" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment?ref=main"

  role       = module.metabase_instance_role.name
  policy_arn = module.metabase_instance_policy.arn
}

# Instance Profile for EC2 instances
resource "aws_iam_instance_profile" "metabase" {
  name = "gameplatform-${var.environment}-metabase-instance-profile"
  role = module.metabase_instance_role.name

  tags = local.tags
}

# Launch Template for Metabase instances
module "metabase_launch_template" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/launch-template?ref=main"

  name          = "gameplatform-${var.environment}-metabase-lt"
  description   = "Launch template for Metabase instances"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile_arn = aws_iam_instance_profile.metabase.arn
  security_group_ids       = [module.metabase_security_group.id, data.aws_security_group.rds.id]

  user_data_base64 = base64encode(file("${path.module}/user_data.sh"))

  block_device_mappings = [
    {
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = var.root_volume_size
        volume_type           = "gp3"
        delete_on_termination = true
        encrypted             = true
      }
    }
  ]

  enable_monitoring = true

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = local.tags
}

# Target Group for ALB
module "metabase_target_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-target-group?ref=main"

  name        = "gameplatform-${var.environment}-metabase-tg"
  port        = var.metabase_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
  target_type = "instance"

  health_check = {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  deregistration_delay = 30

  tags = local.tags
}

# Auto Scaling Group
module "metabase_autoscaling_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/autoscaling-group?ref=main"

  name                      = "gameplatform-${var.environment}-metabase-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  health_check_grace_period = 300
  health_check_type         = "ELB"
  subnet_ids                = data.aws_subnets.private.ids
  target_group_arns         = [module.metabase_target_group.arn]
  launch_template_id        = module.metabase_launch_template.id
  launch_template_version   = "$Latest"

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  tags = merge(
    local.tags,
    {
      Name = "gameplatform-${var.environment}-metabase-instance"
    }
  )
}

# ALB Listener Rule for Metabase
module "metabase_listener_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener-rule?ref=main"

  listener_arn = data.aws_lb_listener.shared_https.arn
  priority     = var.listener_rule_priority

  condition = {
    host_header = {
      values = ["ani-metrics.${var.domain_name}"]
    }
  }

  action = {
    type             = "forward"
    target_group_arn = module.metabase_target_group.arn
  }

  tags = local.tags
}

# Route53 A record for Metabase
module "metabase_dns_record" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-record?ref=main"

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "ani-metrics.${var.domain_name}"
  type    = "A"

  alias = {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = true
  }
}

# CloudWatch Log Group for Metabase
module "metabase_log_group" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group?ref=main"

  name              = "/aws/ec2/gameplatform-${var.environment}-metabase"
  retention_in_days = var.log_retention_days

  tags = local.tags
}