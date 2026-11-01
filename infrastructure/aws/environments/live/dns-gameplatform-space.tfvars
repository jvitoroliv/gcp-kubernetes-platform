# Production Environment Configuration - DNS GamePlatform.Space
# Domain migration from Namecheap to AWS Route53

region      = "sa-east-1"
environment = "live"

# Domain Configuration - gameplatform.example.com migration
domain_name = "gameplatform.example.com"

# Route53 Configuration - Create new hosted zone for migration
create_hosted_zone = true

# SSL Certificate Configuration
create_wildcard_certificate           = true
certificate_validation_method         = "DNS"
certificate_subject_alternative_names = ["gameplatform.example.com"]

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
  Purpose            = "gameplatform-dns-migration"
  Backup             = "daily"
  MonitoringTier     = "critical"
  Domain             = "gameplatform.example.com"
  MigrationFrom      = "namecheap"
  DataClassification = "internal"
  Compliance         = "required"
  DisasterRecovery   = "tier1"
}