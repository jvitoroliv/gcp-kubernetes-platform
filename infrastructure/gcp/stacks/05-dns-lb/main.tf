# -----------------------------------------------------------------------------
# DNS AND LOAD BALANCER STACK
# This stack sets up:
# - Cloud DNS zones and records
# - Global HTTP(S) Load Balancer
# - Google-managed SSL certificates
# - Cloud Armor security policies (optional)
# - Cloud CDN (optional)
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "dns-lb"
    managed_by  = "terraform"
  }, var.labels)

  # Naming convention
  name_prefix = "gameplatform-${var.environment}"
  lb_name     = var.lb_name != "" ? var.lb_name : local.name_prefix
}

# -----------------------------------------------------------------------------
# CLOUD DNS ZONES
# -----------------------------------------------------------------------------

module "dns_zones" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-dns-zone"
  for_each = var.dns_zones

  name        = each.key
  project     = var.project_id
  dns_name    = each.value.dns_name
  description = each.value.description
  visibility  = each.value.visibility

  # Private zone configuration (VPC networks)
  private_visibility_config = each.value.private_visibility_config

  # DNSSEC only for public zones
  dnssec_config = each.value.visibility == "public" && each.value.dnssec ? {
    state = "on"
  } : null

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# CLOUD DNS RECORDS
# -----------------------------------------------------------------------------

module "dns_records" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-dns-record"
  for_each = var.dns_records

  name         = each.value.name
  project      = var.project_id
  managed_zone = each.value.zone_name
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas

  depends_on = [module.dns_zones]
}

# -----------------------------------------------------------------------------
# GLOBAL STATIC IP
# -----------------------------------------------------------------------------

resource "google_compute_global_address" "lb" {
  count = var.enable_global_lb ? 1 : 0

  name         = "${local.lb_name}-ip"
  project      = var.project_id
  address_type = "EXTERNAL"
  ip_version   = "IPV4"

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# GOOGLE-MANAGED SSL CERTIFICATES
# -----------------------------------------------------------------------------

module "ssl_certificates" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/lb-ssl-certificate"
  for_each = var.enable_global_lb ? toset(var.ssl_domains) : []

  name    = "${local.lb_name}-cert-${replace(each.value, ".", "-")}"
  project = var.project_id
  domains = [each.value]
}

# -----------------------------------------------------------------------------
# HEALTH CHECKS
# -----------------------------------------------------------------------------

resource "google_compute_health_check" "backend" {
  for_each = var.enable_global_lb ? var.backend_services : {}

  name    = "${local.lb_name}-hc-${each.key}"
  project = var.project_id

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = each.value.health_check_port
    request_path = each.value.health_check_path
  }
}

# -----------------------------------------------------------------------------
# BACKEND SERVICES
# -----------------------------------------------------------------------------

module "backend_services" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/lb-backend-service"
  for_each = var.enable_global_lb ? var.backend_services : {}

  name                  = "${local.lb_name}-backend-${each.key}"
  project               = var.project_id
  description           = each.value.description
  protocol              = each.value.protocol
  port_name             = each.value.port_name
  timeout_sec           = each.value.timeout_sec
  health_checks         = [google_compute_health_check.backend[each.key].id]
  load_balancing_scheme = "EXTERNAL_MANAGED"

  # CDN configuration
  enable_cdn = each.value.enable_cdn
  cdn_policy = each.value.enable_cdn ? {
    cache_mode        = var.cdn_cache_mode
    default_ttl       = var.cdn_default_ttl
    signed_url_cache_max_age_sec = 0
  } : null

  # Connection draining
  connection_draining_timeout_sec = each.value.connection_draining

  # Security policy
  security_policy = each.value.security_policy

  # Backend will be attached by GKE Ingress NEGs
  # Leave backends empty for now - GKE will manage them

  depends_on = [google_compute_health_check.backend]
}

# -----------------------------------------------------------------------------
# URL MAP
# -----------------------------------------------------------------------------

module "url_map" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/lb-url-map"
  count  = var.enable_global_lb ? 1 : 0

  name            = "${local.lb_name}-url-map"
  project         = var.project_id
  default_service = module.backend_services[var.url_map_default_service].id

  host_rules = [
    for rule in var.host_rules : {
      hosts        = rule.hosts
      path_matcher = rule.path_matcher
    }
  ]

  path_matchers = [
    for name, matcher in var.path_matchers : {
      name            = name
      default_service = module.backend_services[matcher.default_service].id
      path_rules = [
        for rule in matcher.path_rules : {
          paths   = rule.paths
          service = module.backend_services[rule.service].id
        }
      ]
    }
  ]

  depends_on = [module.backend_services]
}

# -----------------------------------------------------------------------------
# TARGET HTTPS PROXY
# -----------------------------------------------------------------------------

module "target_https_proxy" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/lb-target-https-proxy"
  count  = var.enable_global_lb && length(var.ssl_domains) > 0 ? 1 : 0

  name             = "${local.lb_name}-https-proxy"
  project          = var.project_id
  url_map          = module.url_map[0].id
  ssl_certificates = [for cert in module.ssl_certificates : cert.id]

  depends_on = [module.url_map, module.ssl_certificates]
}

# -----------------------------------------------------------------------------
# TARGET HTTP PROXY (for redirect to HTTPS)
# -----------------------------------------------------------------------------

module "target_http_proxy" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/lb-target-http-proxy"
  count  = var.enable_global_lb ? 1 : 0

  name    = "${local.lb_name}-http-proxy"
  project = var.project_id
  url_map = module.url_map[0].id

  depends_on = [module.url_map]
}

# -----------------------------------------------------------------------------
# GLOBAL FORWARDING RULES
# -----------------------------------------------------------------------------

module "https_forwarding_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/lb-global-forwarding-rule"
  count  = var.enable_global_lb && length(var.ssl_domains) > 0 ? 1 : 0

  name                  = "${local.lb_name}-https"
  project               = var.project_id
  ip_address            = google_compute_global_address.lb[0].address
  port_range            = "443"
  target                = module.target_https_proxy[0].id
  load_balancing_scheme = "EXTERNAL_MANAGED"

  labels = local.common_labels

  depends_on = [google_compute_global_address.lb, module.target_https_proxy]
}

module "http_forwarding_rule" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/lb-global-forwarding-rule"
  count  = var.enable_global_lb ? 1 : 0

  name                  = "${local.lb_name}-http"
  project               = var.project_id
  ip_address            = google_compute_global_address.lb[0].address
  port_range            = "80"
  target                = module.target_http_proxy[0].id
  load_balancing_scheme = "EXTERNAL_MANAGED"

  labels = local.common_labels

  depends_on = [google_compute_global_address.lb, module.target_http_proxy]
}

# -----------------------------------------------------------------------------
# CLOUD ARMOR SECURITY POLICY (optional)
# -----------------------------------------------------------------------------

resource "google_compute_security_policy" "main" {
  count = var.enable_cloud_armor ? 1 : 0

  name    = "${local.lb_name}-security-policy"
  project = var.project_id

  # Default rule - allow all
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule - allow all traffic"
  }

  # Custom rules with expression (CEL)
  dynamic "rule" {
    for_each = { for k, v in var.cloud_armor_rules : k => v if v.expression != null }
    content {
      action   = rule.value.action
      priority = rule.value.priority

      match {
        expr {
          expression = rule.value.expression
        }
      }

      description = rule.value.description
    }
  }

  # Custom rules with src_ranges (IP-based)
  dynamic "rule" {
    for_each = { for k, v in var.cloud_armor_rules : k => v if v.src_ranges != null }
    content {
      action   = rule.value.action
      priority = rule.value.priority

      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = rule.value.src_ranges
        }
      }

      description = rule.value.description
    }
  }
}

# =============================================================================
# GATEWAY API STATIC IP (Legacy - for Gateway API if needed)
# =============================================================================

resource "google_compute_global_address" "gateway" {
  count = var.enable_gateway_ip ? 1 : 0

  name         = var.gateway_ip_name != "" ? var.gateway_ip_name : "${local.name_prefix}-gateway-ip"
  project      = var.project_id
  address_type = "EXTERNAL"
  ip_version   = "IPV4"

  labels = local.common_labels
}

# =============================================================================
# REGIONAL INGRESS IP (for GKE nginx-ingress LoadBalancer)
# =============================================================================
# This creates a REGIONAL static IP for use with GKE LoadBalancer services.
# Unlike global IPs, regional IPs work correctly with GKE's regional LB.

resource "google_compute_address" "regional_ingress" {
  count = var.enable_regional_ingress_ip ? 1 : 0

  name         = var.regional_ingress_ip_name != "" ? var.regional_ingress_ip_name : "${local.name_prefix}-ingress-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  # If a specific address is provided, use it (for importing existing IPs)
  address = var.regional_ingress_ip_address != "" ? var.regional_ingress_ip_address : null

  labels = local.common_labels

  lifecycle {
    # Prevent destruction of production IPs
    prevent_destroy = false
  }
}

# =============================================================================
# APPLICATION LOAD BALANCER (AWS ALB Equivalent)
# Single IP with hostname-based routing for all services on port 443
# Also supports custom ports via TCP Proxy on the same IP
# =============================================================================

# Global Static IP for Application Load Balancer (shared by all services)
resource "google_compute_global_address" "alb" {
  count = var.enable_alb ? 1 : 0

  name         = "${local.name_prefix}-alb-ip"
  project      = var.project_id
  address_type = "EXTERNAL"
  ip_version   = "IPV4"

  labels = local.common_labels
}

# Google-managed SSL Certificate for ALB (wildcard)
resource "google_compute_managed_ssl_certificate" "alb" {
  count = var.enable_alb && length(var.alb_ssl_domains) > 0 ? 1 : 0

  name    = "${local.name_prefix}-alb-cert"
  project = var.project_id

  managed {
    domains = var.alb_ssl_domains
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Health Checks for ALB backend services
resource "google_compute_health_check" "alb" {
  for_each = var.enable_alb ? var.alb_services : {}

  name    = "${local.name_prefix}-alb-hc-${each.key}"
  project = var.project_id

  check_interval_sec  = 15
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = each.value.backend_port
    request_path = each.value.health_check_path
  }
}

# Backend Services for ALB (HTTP protocol for Application LB)
resource "google_compute_backend_service" "alb" {
  for_each = var.enable_alb ? var.alb_services : {}

  name        = "${local.name_prefix}-alb-backend-${each.key}"
  project     = var.project_id
  description = each.value.description != "" ? each.value.description : "ALB backend for ${each.key}"

  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = each.value.timeout_sec
  load_balancing_scheme = "EXTERNAL_MANAGED"

  health_checks = [google_compute_health_check.alb[each.key].id]

  # Backends will be populated by NEGs from GKE Services
  # Use dynamic block to add NEGs if provided
  dynamic "backend" {
    for_each = each.value.neg_self_links != null ? each.value.neg_self_links : []
    content {
      group           = backend.value
      balancing_mode  = "RATE"
      max_rate_per_endpoint = 100
    }
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL Map for ALB (hostname-based routing)
# Only created when alb_services is not empty (Terraform-managed ALB)
# When empty, GKE Ingress Controller creates its own URL map
resource "google_compute_url_map" "alb" {
  count = var.enable_alb && length(var.alb_services) > 0 ? 1 : 0

  name            = "${local.name_prefix}-alb-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.alb[var.alb_default_service].id

  dynamic "host_rule" {
    for_each = var.alb_services
    content {
      hosts        = host_rule.value.hostnames
      path_matcher = host_rule.key
    }
  }

  dynamic "path_matcher" {
    for_each = var.alb_services
    content {
      name            = path_matcher.key
      default_service = google_compute_backend_service.alb[path_matcher.key].id
    }
  }

  depends_on = [google_compute_backend_service.alb]
}

# HTTPS Target Proxy for ALB
# Only created when using Terraform-managed ALB (not GKE Ingress)
resource "google_compute_target_https_proxy" "alb" {
  count = var.enable_alb && length(var.alb_services) > 0 && length(var.alb_ssl_domains) > 0 ? 1 : 0

  name             = "${local.name_prefix}-alb-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.alb[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.alb[0].id]

  depends_on = [google_compute_url_map.alb, google_compute_managed_ssl_certificate.alb]
}

# HTTP Target Proxy for ALB (redirect to HTTPS)
# Only created when using Terraform-managed ALB (not GKE Ingress)
resource "google_compute_url_map" "alb_http_redirect" {
  count = var.enable_alb && length(var.alb_services) > 0 ? 1 : 0

  name    = "${local.name_prefix}-alb-http-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "alb" {
  count = var.enable_alb && length(var.alb_services) > 0 ? 1 : 0

  name    = "${local.name_prefix}-alb-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.alb_http_redirect[0].id

  depends_on = [google_compute_url_map.alb_http_redirect]
}

# HTTPS Forwarding Rule (port 443)
# Only created when using Terraform-managed ALB (not GKE Ingress)
resource "google_compute_global_forwarding_rule" "alb_https" {
  count = var.enable_alb && length(var.alb_services) > 0 && length(var.alb_ssl_domains) > 0 ? 1 : 0

  name                  = "${local.name_prefix}-alb-https"
  project               = var.project_id
  ip_address            = google_compute_global_address.alb[0].address
  port_range            = "443"
  target                = google_compute_target_https_proxy.alb[0].id
  load_balancing_scheme = "EXTERNAL_MANAGED"

  labels = local.common_labels

  depends_on = [google_compute_global_address.alb, google_compute_target_https_proxy.alb]
}

# HTTP Forwarding Rule (port 80 - redirects to HTTPS)
# Only created when using Terraform-managed ALB (not GKE Ingress)
resource "google_compute_global_forwarding_rule" "alb_http" {
  count = var.enable_alb && length(var.alb_services) > 0 ? 1 : 0

  name                  = "${local.name_prefix}-alb-http"
  project               = var.project_id
  ip_address            = google_compute_global_address.alb[0].address
  port_range            = "80"
  target                = google_compute_target_http_proxy.alb[0].id
  load_balancing_scheme = "EXTERNAL_MANAGED"

  labels = local.common_labels

  depends_on = [google_compute_global_address.alb, google_compute_target_http_proxy.alb]
}

# =============================================================================
# TCP PROXY LOAD BALANCERS FOR CUSTOM PORTS (Same IP as ALB)
# Allows access to services on custom ports (7350, 6969, 9933, etc.)
# =============================================================================

# Health Checks for TCP Proxy services
resource "google_compute_health_check" "tcp_proxy" {
  for_each = var.enable_alb ? var.alb_tcp_services : {}

  name    = "${local.name_prefix}-tcp-hc-${each.key}"
  project = var.project_id

  check_interval_sec  = 15
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  tcp_health_check {
    port = each.value.backend_port
  }
}

# Backend Services for TCP Proxy
resource "google_compute_backend_service" "tcp_proxy" {
  for_each = var.enable_alb ? var.alb_tcp_services : {}

  name        = "${local.name_prefix}-tcp-backend-${each.key}"
  project     = var.project_id
  description = each.value.description != "" ? each.value.description : "TCP Proxy backend for ${each.key}"

  protocol              = "TCP"
  timeout_sec           = each.value.timeout_sec
  load_balancing_scheme = "EXTERNAL_MANAGED"

  health_checks = [google_compute_health_check.tcp_proxy[each.key].id]

  # Backends will be populated by NEGs from GKE Services
  dynamic "backend" {
    for_each = each.value.neg_self_links != null ? each.value.neg_self_links : []
    content {
      group          = backend.value
      balancing_mode = "CONNECTION"
    }
  }
}

# TCP Proxy Targets
resource "google_compute_target_tcp_proxy" "tcp_proxy" {
  for_each = var.enable_alb ? var.alb_tcp_services : {}

  name            = "${local.name_prefix}-tcp-proxy-${each.key}"
  project         = var.project_id
  backend_service = google_compute_backend_service.tcp_proxy[each.key].id

  depends_on = [google_compute_backend_service.tcp_proxy]
}

# TCP Forwarding Rules (custom ports, same IP as ALB)
resource "google_compute_global_forwarding_rule" "tcp_proxy" {
  for_each = var.enable_alb ? var.alb_tcp_services : {}

  name                  = "${local.name_prefix}-tcp-fwd-${each.key}"
  project               = var.project_id
  ip_address            = google_compute_global_address.alb[0].address
  port_range            = tostring(each.value.port)
  target                = google_compute_target_tcp_proxy.tcp_proxy[each.key].id
  load_balancing_scheme = "EXTERNAL_MANAGED"

  labels = local.common_labels

  depends_on = [google_compute_global_address.alb, google_compute_target_tcp_proxy.tcp_proxy]
}

# =============================================================================
# SSL PROXY LOAD BALANCER (Custom Ports like AWS ALB)
# This creates HTTPS listeners on custom ports (7350, 6969, 9933, etc.)
# similar to how AWS ALB handles multiple HTTPS listeners
# Uses the SAME IP as ALB for single-IP architecture (like AWS ALB)
# =============================================================================

# NOTE: SSL Proxy uses the same IP as ALB (google_compute_global_address.alb)
# No separate IP needed - this replicates AWS ALB behavior where all ports
# are accessible on the same IP address

# Google-managed SSL Certificate for SSL Proxy
# Only created when ssl_proxy_external_certificate is NOT provided
resource "google_compute_managed_ssl_certificate" "ssl_proxy" {
  count = var.enable_ssl_proxy && var.ssl_proxy_external_certificate == "" && length(var.ssl_proxy_certificate_domains) > 0 ? 1 : 0

  name    = "${local.name_prefix}-ssl-proxy-cert"
  project = var.project_id

  managed {
    domains = var.ssl_proxy_certificate_domains
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Health Checks for SSL Proxy backend services (TCP health checks)
resource "google_compute_health_check" "ssl_proxy" {
  for_each = var.enable_ssl_proxy ? var.ssl_proxy_services : {}

  name    = "${local.name_prefix}-ssl-proxy-hc-${each.key}"
  project = var.project_id

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = each.value.backend_port
    request_path = each.value.health_check_path
  }
}

# Backend Services for SSL Proxy (TCP protocol)
resource "google_compute_backend_service" "ssl_proxy" {
  for_each = var.enable_ssl_proxy ? var.ssl_proxy_services : {}

  name        = "${local.name_prefix}-ssl-proxy-backend-${each.key}"
  project     = var.project_id
  description = each.value.description != "" ? each.value.description : "SSL Proxy backend for ${each.key}"

  protocol              = "TCP"
  port_name             = "tcp-${each.value.backend_port}"
  timeout_sec           = each.value.timeout_sec
  load_balancing_scheme = "EXTERNAL"

  health_checks = [google_compute_health_check.ssl_proxy[each.key].id]

  # Use NEGs from GKE Services if provided
  dynamic "backend" {
    for_each = each.value.neg_self_links != null ? each.value.neg_self_links : []
    content {
      group                        = backend.value
      balancing_mode               = "CONNECTION"
      max_connections_per_endpoint = 1000
    }
  }
}

# SSL Proxy Targets (one per service/port)
# Uses external certificate (e.g., GKE ManagedCertificate) when provided,
# otherwise uses Terraform-managed certificate if domains are specified.
resource "google_compute_target_ssl_proxy" "ssl_proxy" {
  for_each = var.enable_ssl_proxy ? var.ssl_proxy_services : {}

  name            = "${local.name_prefix}-ssl-proxy-${each.key}"
  project         = var.project_id
  backend_service = google_compute_backend_service.ssl_proxy[each.key].id
  ssl_certificates = var.ssl_proxy_external_certificate != "" ? [var.ssl_proxy_external_certificate] : (
    length(var.ssl_proxy_certificate_domains) > 0 ? [google_compute_managed_ssl_certificate.ssl_proxy[0].id] : []
  )

  depends_on = [google_compute_backend_service.ssl_proxy, google_compute_managed_ssl_certificate.ssl_proxy]
}

# Global Forwarding Rules (one per port, all using SAME IP as ALB)
resource "google_compute_global_forwarding_rule" "ssl_proxy" {
  for_each = var.enable_ssl_proxy && var.enable_alb ? var.ssl_proxy_services : {}

  name                  = "${local.name_prefix}-ssl-proxy-fwd-${each.key}"
  project               = var.project_id
  ip_address            = google_compute_global_address.alb[0].address  # Use ALB IP for single-IP architecture
  port_range            = tostring(each.value.port)
  target                = google_compute_target_ssl_proxy.ssl_proxy[each.key].id
  load_balancing_scheme = "EXTERNAL"

  labels = local.common_labels

  depends_on = [google_compute_global_address.alb, google_compute_target_ssl_proxy.ssl_proxy]
}
