# Production Environment Configuration - DNS and ALB
# Production-grade high availability settings for gameplatform.click

region      = "sa-east-1"
environment = "live"

# Domain Configuration - Subdomain delegation like dev
domain_name = "live.gameplatform.click" # Using subdomain for live environment

# Route53 Configuration - Cross-account delegation
create_hosted_zone = true # Create live.gameplatform.click zone in live account
# parent_domain_zone_id = "Z07010512WPMFPM8RBKSN"  # gameplatform.click zone in account 777777777777
# cross_account_delegation = true  # Requires manual NS record creation in parent account

# SSL Certificate Configuration
create_wildcard_certificate           = true
certificate_validation_method         = "DNS"
certificate_subject_alternative_names = []

# ALB Configuration - Production settings
create_shared_alb          = true
alb_scheme                 = "internet-facing"
alb_type                   = "application"
enable_deletion_protection = true # Enable deletion protection in production
enable_http2               = true
idle_timeout               = 300 # Longer timeout for production

# Access Logs Configuration
enable_access_logs         = true
access_logs_retention_days = 90 # Extended retention for production

# WAF Configuration - Enable for production security
enable_waf = true
waf_rules = {
  rate_limit = {
    name     = "RateLimitRule"
    priority = 1
    limit    = 2000 # Requests per 5-minute window
  }
  ip_reputation = {
    name     = "IPReputationRule"
    priority = 2
  }
  known_bad_inputs = {
    name     = "KnownBadInputsRule"
    priority = 3
  }
}

# Default Target Group Configuration
default_target_group_config = {
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 60 # Longer deregistration delay for production

  health_check = {
    enabled             = true
    healthy_threshold   = 3 # More strict health checks
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
}

# Additional Tags
additional_tags = {
  Owner              = "infrastructure-team"
  CostCenter         = "production"
  Environment        = "live"
  Purpose            = "shared-dns-alb"
  Backup             = "daily"
  MonitoringTier     = "critical"
  Domain             = "gameplatform.click"
  CrossAccount       = "true"
  DataClassification = "internal"
  Compliance         = "required"
  DisasterRecovery   = "tier1"
}