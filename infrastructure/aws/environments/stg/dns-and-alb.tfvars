# Staging Environment Configuration - DNS and ALB
# Settings for gameplatform.click cross-account domain

region      = "us-east-1"
environment = "stg"

# Domain Configuration - using gameplatform.click subdomain
domain_name = "stg.gameplatform.click"

# Route53 Configuration - Cross-account delegation
create_hosted_zone = true # Create stg.gameplatform.click zone in sandbox account
# parent_domain_zone_id = "Z07010512WPMFPM8RBKSN"  # gameplatform.click zone in account 777777777777
# cross_account_delegation = true  # Requires manual NS record creation in parent account

# SSL Certificate Configuration
create_wildcard_certificate           = true
certificate_validation_method         = "DNS"
certificate_subject_alternative_names = []

# ALB Configuration - Staging settings (production-like but flexible)
create_shared_alb          = true
alb_scheme                 = "internet-facing"
alb_type                   = "application"
enable_deletion_protection = false # Keep false for staging to allow easy cleanup/rebuild
enable_http2               = true
idle_timeout               = 120 # Mid-range timeout between dev and live

# Access Logs Configuration
enable_access_logs         = true
access_logs_retention_days = 14 # Moderate retention for staging

# WAF Configuration (disabled for staging to reduce costs)
enable_waf = false

# Default Target Group Configuration
default_target_group_config = {
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 45 # Mid-range between dev and production

  health_check = {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 8
    interval            = 30
    path                = "/health"
    matcher             = "200,404" # Allow 404 for default target group
    port                = "traffic-port"
    protocol            = "HTTP"
  }
}

# Additional Tags
additional_tags = {
  Owner              = "infrastructure-team"
  CostCenter         = "engineering"
  Environment        = "staging"
  Purpose            = "pre-production-testing"
  Backup             = "weekly"
  MonitoringTier     = "high"
  Domain             = "gameplatform.click"
  CrossAccount       = "true"
  DataClassification = "internal"
  Compliance         = "testing"
}
