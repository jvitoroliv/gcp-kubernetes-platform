# -----------------------------------------------------------------------------
# MIDDLEWARE LOAD BALANCER STACK - LEGACY
# Creates HTTPS Load Balancer for middleware VM with TLS termination
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "middleware-lb"
    managed_by  = "terraform"
  }, var.labels)
}

# -----------------------------------------------------------------------------
# STATIC EXTERNAL IP
# -----------------------------------------------------------------------------

resource "google_compute_global_address" "lb_ip" {
  name         = "${var.lb_name}-ip"
  project      = var.project_id
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# -----------------------------------------------------------------------------
# MANAGED SSL CERTIFICATE
# -----------------------------------------------------------------------------

resource "google_compute_managed_ssl_certificate" "ssl_cert" {
  name    = "${var.lb_name}-cert"
  project = var.project_id

  managed {
    domains = var.ssl_domains
  }
}

# -----------------------------------------------------------------------------
# HEALTH CHECK
# -----------------------------------------------------------------------------

resource "google_compute_health_check" "middleware_health" {
  name    = "${var.lb_name}-health"
  project = var.project_id

  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = var.service_port
    request_path = "/"
  }
}

# -----------------------------------------------------------------------------
# INSTANCE GROUP (Unmanaged, pointing to the VM)
# -----------------------------------------------------------------------------

resource "google_compute_instance_group" "middleware_group" {
  name      = "${var.lb_name}-instance-group"
  project   = var.project_id
  zone      = var.vm_zone
  instances = [var.vm_self_link]

  named_port {
    name = "http"
    port = var.service_port
  }
}

# -----------------------------------------------------------------------------
# BACKEND SERVICE
# -----------------------------------------------------------------------------

resource "google_compute_backend_service" "middleware_backend" {
  name        = "${var.lb_name}-backend"
  project     = var.project_id
  description = "Backend service for Rogues middleware"

  protocol                        = "HTTP"
  port_name                       = "http"
  timeout_sec                     = 300
  connection_draining_timeout_sec = 300
  load_balancing_scheme           = "EXTERNAL_MANAGED"

  health_checks = [google_compute_health_check.middleware_health.id]

  backend {
    group           = google_compute_instance_group.middleware_group.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  # Custom response headers for CORS/COEP
  custom_response_headers = [
    "Cross-Origin-Opener-Policy: same-origin",
    "Cross-Origin-Embedder-Policy: require-corp",
    "Access-Control-Allow-Origin: *",
    "Access-Control-Allow-Methods: OPTIONS,GET,POST"
  ]

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# -----------------------------------------------------------------------------
# URL MAP
# -----------------------------------------------------------------------------

resource "google_compute_url_map" "url_map" {
  name            = "${var.lb_name}-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.middleware_backend.id
}

# -----------------------------------------------------------------------------
# HTTPS PROXY
# -----------------------------------------------------------------------------

resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "${var.lb_name}-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.ssl_cert.id]
}

# -----------------------------------------------------------------------------
# FORWARDING RULE (HTTPS on 443)
# -----------------------------------------------------------------------------

resource "google_compute_global_forwarding_rule" "https_rule" {
  name                  = "${var.lb_name}-https-rule"
  project               = var.project_id
  target                = google_compute_target_https_proxy.https_proxy.id
  port_range            = "443"
  ip_address            = google_compute_global_address.lb_ip.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# HTTP TO HTTPS REDIRECT
# -----------------------------------------------------------------------------

resource "google_compute_url_map" "http_redirect" {
  name    = "${var.lb_name}-http-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "${var.lb_name}-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http_rule" {
  name                  = "${var.lb_name}-http-rule"
  project               = var.project_id
  target                = google_compute_target_http_proxy.http_proxy.id
  port_range            = "80"
  ip_address            = google_compute_global_address.lb_ip.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"

  labels = local.common_labels
}
