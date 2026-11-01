locals {
  common_tags = {
    Project         = "GamePlatform"
    Environment     = var.environment
    Component       = "DNS-ALB"
    ManagedBy       = "terraform"
    TerraformModule = "gameplatform-shared-infrastructure/dns-and-alb"
  }

  tags = merge(local.common_tags, var.additional_tags)
}

# Data sources for networking (assuming networking module was deployed first)
data "aws_vpc" "main" {
  tags = {
    Name = "gameplatform-${var.environment}-vpc"
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

# Route53 Hosted Zone
module "hosted_zone" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-hosted-zone"
  count  = var.create_hosted_zone ? 1 : 0

  name = var.domain_name

  tags = merge(local.tags, {
    Purpose = "DNS-Management"
  })
}

# Get existing hosted zone if not creating a new one
data "aws_route53_zone" "existing" {
  count = var.create_hosted_zone ? 0 : 1

  name         = var.domain_name
  private_zone = false
}

# Local values for hosted zone reference
locals {
  hosted_zone_id   = var.create_hosted_zone ? module.hosted_zone[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  hosted_zone_name = var.create_hosted_zone ? module.hosted_zone[0].name : data.aws_route53_zone.existing[0].name
}

# ACM Certificate for wildcard domain
module "wildcard_certificate" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/acm-certificate"
  count  = var.create_wildcard_certificate ? 1 : 0

  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = var.certificate_subject_alternative_names
  # Module requires DNS validation settings via object
  validation_dns = {
    hosted_zone_id = local.hosted_zone_id
  }

  tags = merge(local.tags, {
    Purpose = "SSL-Certificate"
    Domain  = var.domain_name
  })
}

# Security Group for ALB
module "alb_security_group" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/security-group"
  count  = var.create_shared_alb ? 1 : 0

  name        = "gameplatform-${var.environment}-alb-sg"
  description = "Security group for shared Application Load Balancer"
  vpc_id      = data.aws_vpc.main.id

  ingress_rules = [
    {
      description = "HTTP from internet"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS from internet"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS Nakama alternative ports"
      from_port   = 7349
      to_port     = 7351
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS AES service"
      from_port   = 1988
      to_port     = 1988
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS AHSAT service"
      from_port   = 6969
      to_port     = 6969
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS AIS service"
      from_port   = 5050
      to_port     = 5050
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS APS service"
      from_port   = 4444
      to_port     = 4444
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS AFS service"
      from_port   = 9933
      to_port     = 9933
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  egress_rules = [
    {
      description = "All outbound to VPC"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
    }
  ]

  tags = merge(local.tags, {
    Purpose = "ALB-Security"
  })
}

# S3 Bucket for ALB Access Logs (if enabled)
module "alb_access_logs_bucket" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/s3-bucket"
  count  = var.create_shared_alb && var.enable_access_logs ? 1 : 0

  name = "gameplatform-${var.environment}-alb-access-logs-${random_id.bucket_suffix[0].hex}"

  tags = merge(local.tags, {
    Purpose = "ALB-Access-Logs"
  })
}

# Random suffix for S3 bucket name uniqueness
resource "random_id" "bucket_suffix" {
  count       = var.create_shared_alb && var.enable_access_logs ? 1 : 0
  byte_length = 8
}

# S3 Bucket Lifecycle Configuration for access logs
resource "aws_s3_bucket_lifecycle_configuration" "alb_access_logs" {
  count  = var.create_shared_alb && var.enable_access_logs ? 1 : 0
  bucket = module.alb_access_logs_bucket[0].id

  rule {
    id     = "delete_old_logs"
    status = "Enabled"

    # Apply lifecycle to the ALB access logs prefix
    filter {
      prefix = "alb-access-logs"
    }

    expiration {
      days = var.access_logs_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

# S3 Bucket Policy for ALB access logs
resource "aws_s3_bucket_policy" "alb_access_logs" {
  count  = var.create_shared_alb && var.enable_access_logs ? 1 : 0
  bucket = module.alb_access_logs_bucket[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_elb_service_account.main[0].id}:root"
        }
        Action   = "s3:PutObject"
        Resource = "${module.alb_access_logs_bucket[0].arn}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${module.alb_access_logs_bucket[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Get AWS ELB service account for access logs
data "aws_elb_service_account" "main" {
  count = var.create_shared_alb && var.enable_access_logs ? 1 : 0
}

# Default Target Group for ALB (returns 404 for unmatched requests)
module "default_target_group" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-target-group"
  count  = var.create_shared_alb ? 1 : 0

  name        = "gameplatform-${var.environment}-default-tg"
  port        = var.default_target_group_config.port
  protocol    = var.default_target_group_config.protocol
  vpc_id      = data.aws_vpc.main.id
  target_type = var.default_target_group_config.target_type

  health_check         = var.default_target_group_config.health_check
  deregistration_delay = var.default_target_group_config.deregistration_delay

  tags = merge(local.tags, {
    Purpose = "Default-Target-Group"
  })
}

# Application Load Balancer
module "shared_alb" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb"
  count  = var.create_shared_alb ? 1 : 0

  name = "gameplatform-${var.environment}-shared-alb"
  # Module expects a list of subnet IDs under `subnets`
  subnets = data.aws_subnets.public.ids
  # Map scheme -> internal flag expected by module
  internal = var.alb_scheme == "internal"
  # Security group IDs list
  security_group_ids = [module.alb_security_group[0].id]
  # Module variable name is `deletion_protection`
  deletion_protection = var.enable_deletion_protection
  idle_timeout        = var.idle_timeout
  enable_http2        = var.enable_http2

  # Access logs configuration
  access_logs = var.enable_access_logs ? {
    bucket  = module.alb_access_logs_bucket[0].id
    enabled = true
    prefix  = "alb-access-logs"
  } : null

  tags = merge(local.tags, {
    Purpose = "Shared-Load-Balancer"
  })
}

# HTTP Listener (redirects to HTTPS)
module "http_listener" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener"
  count  = var.create_shared_alb ? 1 : 0

  load_balancer_arn = module.shared_alb[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action = {
    type = "redirect"
    redirect = {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = local.tags
}

# HTTPS Listener
module "https_listener" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener"
  count  = var.create_shared_alb && var.create_wildcard_certificate ? 1 : 0

  load_balancer_arn = module.shared_alb[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = module.wildcard_certificate[0].certificate_arn

  default_action = {
    type             = "forward"
    target_group_arn = module.default_target_group[0].arn
  }

  tags = local.tags
}

# Route53 A record for ALB (apex domain)
module "apex_domain_record" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-record"
  count  = var.create_shared_alb ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias = {
    name                   = module.shared_alb[0].dns_name
    zone_id                = module.shared_alb[0].zone_id
    evaluate_target_health = true
  }
}

# Route53 A record for ALB (wildcard)
module "wildcard_domain_record" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route53-record"
  count  = var.create_shared_alb ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = "*.${var.domain_name}"
  type    = "A"

  alias = {
    name                   = module.shared_alb[0].dns_name
    zone_id                = module.shared_alb[0].zone_id
    evaluate_target_health = true
  }
}