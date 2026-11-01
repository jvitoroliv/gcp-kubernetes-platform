# ======================================================================
# MAINTENANCE MODE - CUSTOM ERROR PAGE
# ======================================================================
# This module creates a high-priority ALB listener rule that returns
# a custom HTML maintenance page when enabled.
#
# Usage:
#   Set enable_maintenance_mode = true in tfvars to activate
#   Set enable_maintenance_mode = false to deactivate (normal operation)
#
# Coverage:
#   - Planned maintenance (503)
#   - Catch-all for unmatched paths (404-like behavior)
#   - Target group failures (503 from ALB)
#
# Note: ALB cannot intercept errors FROM target groups (502/503/504).
#       For complete error coverage, use CloudFront with custom error pages.
# ======================================================================

locals {
  # Load maintenance HTML from file
  maintenance_html = file("${path.module}/maintenance.html")
}

# ======================================================================
# MAINTENANCE MODE - LOBBY APP
# ======================================================================

# Maintenance Page Listener Rule for Lobby (app.gameplatform.example.com)
# Priority 50 executes BEFORE normal lobby rule (priority 200)
module "lobby_maintenance_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener-rule?ref=main"

  # Only create when maintenance mode is enabled
  count = var.enable_maintenance_mode ? 1 : 0

  listener_arn = data.aws_lb_listener.shared_https.arn
  priority     = 50 # HIGHER priority (lower number) than lobby rule

  # Match app.gameplatform.example.com (same as lobby)
  condition = {
    host_header = {
      values = ["app.${var.domain_name}"]
    }
  }

  # Return 503 with custom HTML
  action = {
    type = "fixed-response"
    fixed_response = {
      content_type = "text/html"
      message_body = local.maintenance_html
      status_code  = "503"
    }
  }

  tags = merge(local.tags, {
    Purpose = "Maintenance-Page-Lobby"
  })
}

# ======================================================================
# CATCH-ALL FALLBACK - UNMATCHED PATHS
# ======================================================================
# Returns maintenance page for any unmatched requests to *.gameplatform.example.com
# This acts as a fallback when no other listener rule matches

module "fallback_maintenance_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/alb-listener-rule?ref=main"

  # Only create when maintenance mode is enabled
  count = var.enable_maintenance_mode ? 1 : 0

  listener_arn = data.aws_lb_listener.shared_https.arn
  priority     = 49999 # LOWEST priority (executes last if nothing else matches)

  # Match all requests to *.gameplatform.example.com
  condition = {
    host_header = {
      values = ["*.${var.domain_name}"]
    }
  }

  # Return 503 with custom HTML
  action = {
    type = "fixed-response"
    fixed_response = {
      content_type = "text/html"
      message_body = local.maintenance_html
      status_code  = "503"
    }
  }

  tags = merge(local.tags, {
    Purpose = "Maintenance-Page-Fallback"
  })
}
