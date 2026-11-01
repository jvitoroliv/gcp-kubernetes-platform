# Development Environment Configuration - DNS and ALB
# Settings for gameplatform.click cross-account domain

region      = "us-east-1"
environment = "dev"

# Domain Configuration - usando gameplatform.click
domain_name = "dev.gameplatform.click"

# Route53 Configuration - Cross-account delegation
create_hosted_zone = true # Create dev.gameplatform.click zone in sandbox account
# parent_domain_zone_id = "Z07010512WPMFPM8RBKSN"  # gameplatform.click zone in account 777777777777
# cross_account_delegation = true  # Requires manual NS record creation in parent account

# SSL Certificate Configuration
create_wildcard_certificate           = true
certificate_validation_method         = "DNS"
certificate_subject_alternative_names = []

# ALB Configuration
create_shared_alb          = true
alb_scheme                 = "internet-facing"
alb_type                   = "application"
enable_deletion_protection = false # Keep false for dev to allow easy cleanup
enable_http2               = true
idle_timeout               = 60

# Access Logs Configuration
enable_access_logs         = true
access_logs_retention_days = 3 # Short retention for dev

# WAF Configuration (disabled for dev to reduce costs)
enable_waf = false

# Default Target Group Configuration
default_target_group_config = {
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 30

  health_check = {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200,404" # Allow 404 for default target group
    port                = "traffic-port"
    protocol            = "HTTP"
  }
}

# Additional Tags
additional_tags = {
  Owner        = "infrastructure-team"
  CostCenter   = "development"
  Environment  = "dev"
  Purpose      = "shared-dns-alb"
  Backup       = "none"
  Domain       = "gameplatform.click"
  CrossAccount = "true"
}