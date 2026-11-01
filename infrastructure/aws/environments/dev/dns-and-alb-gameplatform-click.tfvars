# USAGE SCENARIOS:

# 1. Current file (dns-and-alb.tfvars):

# - Scenario: First deployment or standalone setup
# - Behavior: Creates a new hosted zone dev.gameplatform.click in the sandbox account
# - Requires: Manual delegation of NS records in the parent account (777777777777)
# - Usage: Initial setup, isolated development

# 2. Alternative file (dns-and-alb-gameplatform-click.tfvars):

# - Scenario: Direct use of the existing cross-account zone
# - Behavior: Uses the existing gameplatform.click zone in account 777777777777
# - Requires: Cross-account permissions to manage the parent zone
# - Usage: Production, full integration between accounts

# WHEN TO USE EACH:

# # Development/Initial Setup (current):
# terraform plan -var-file="../../environments/dev/dns-and-alb.tfvars"

# # Direct cross-account (alternative):
# terraform plan -var-file="../../environments/dev/dns-and-alb-gameplatform-click.tfvars"

# WORKFLOW INTEGRATION:

# The dns-and-alb-gameplatform-click.tfvars file would be used when you want to:
# - Skip creating a separate zone
# - Directly use the parent zone via cross-account
# - Simplify DNS configuration (without manual delegation)

# In short: It's an alternative configuration for scenarios where you have direct access to the main gameplatform.click zone and don't
# need to create a delegated subzone.

# # Development Environment Configuration - DNS and ALB
# # Settings for gameplatform.click cross-account domain

# region      = "us-east-1"
# environment = "dev"

# # Domain Configuration - usando gameplatform.click
# domain_name = "dev.gameplatform.click"

# # Route53 Configuration - CROSS ACCOUNT
# create_hosted_zone = false  # Zone already exists in account 777777777777
# hosted_zone_id = "Z07010512WPMFPM8RBKSN"  # gameplatform.click zone ID

# # SSL Certificate Configuration
# create_wildcard_certificate         = true
# certificate_validation_method       = "DNS"
# certificate_subject_alternative_names = []

# # ALB Configuration
# create_shared_alb          = true
# alb_scheme                 = "internet-facing"
# alb_type                   = "application"
# enable_deletion_protection = false  # Keep false for dev to allow easy cleanup
# enable_http2               = true
# idle_timeout               = 60

# # Access Logs Configuration
# enable_access_logs         = true
# access_logs_retention_days = 7  # Short retention for dev

# # WAF Configuration (disabled for dev to reduce costs)
# enable_waf = false

# # Default Target Group Configuration
# default_target_group_config = {
#   port                = 80
#   protocol            = "HTTP"
#   target_type         = "ip"
#   deregistration_delay = 30

#   health_check = {
#     enabled             = true
#     healthy_threshold   = 2
#     unhealthy_threshold = 3
#     timeout             = 5
#     interval            = 30
#     path                = "/health"
#     matcher             = "200,404"  # Allow 404 for default target group
#     port                = "traffic-port"
#     protocol            = "HTTP"
#   }
# }

# # Additional Tags
# additional_tags = {
#   Owner       = "infrastructure-team"
#   CostCenter  = "development"
#   Environment = "dev"
#   Purpose     = "shared-dns-alb"
#   Backup      = "none"
#   Domain      = "gameplatform.click"
#   CrossAccount = "true"
# }