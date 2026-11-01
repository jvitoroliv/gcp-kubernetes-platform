# -----------------------------------------------------------------------------
# VM SERVICES LOAD BALANCER STACK - LEGACY
# Creates HTTPS Load Balancer for VM-based services (afs, nakama, ahsat, acrypt)
# with host-based routing and TLS termination
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "vm-services-lb"
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
# HEALTH CHECKS (one per service with appropriate port)
# -----------------------------------------------------------------------------

resource "google_compute_health_check" "service_health" {
  for_each = var.backend_services

  name    = "${var.lb_name}-${each.key}-health"
  project = var.project_id

  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  tcp_health_check {
    port = each.value.port
  }
}

# -----------------------------------------------------------------------------
# INSTANCE GROUP (Unmanaged, pointing to the VM)
# -----------------------------------------------------------------------------

resource "google_compute_instance_group" "vm_group" {
  name      = "${var.lb_name}-instance-group"
  project   = var.project_id
  zone      = var.vm_zone
  instances = [var.vm_self_link]

  dynamic "named_port" {
    for_each = var.backend_services
    content {
      name = named_port.key
      port = named_port.value.port
    }
  }
}

# -----------------------------------------------------------------------------
# BACKEND SERVICES (one per service)
# -----------------------------------------------------------------------------

resource "google_compute_backend_service" "service_backend" {
  for_each = var.backend_services

  name        = "${var.lb_name}-${each.key}-backend"
  project     = var.project_id
  description = "Backend service for ${each.key}"

  protocol                        = "HTTP"
  port_name                       = each.key
  timeout_sec                     = 30
  connection_draining_timeout_sec = 300
  load_balancing_scheme           = "EXTERNAL_MANAGED"

  health_checks = [google_compute_health_check.service_health[each.key].id]

  backend {
    group           = google_compute_instance_group.vm_group.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# -----------------------------------------------------------------------------
# URL MAP (Host-based routing)
# -----------------------------------------------------------------------------

resource "google_compute_url_map" "url_map" {
  name            = "${var.lb_name}-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.service_backend[var.default_service].id

  dynamic "host_rule" {
    for_each = var.backend_services
    content {
      hosts        = host_rule.value.hosts
      path_matcher = host_rule.key
    }
  }

  dynamic "path_matcher" {
    for_each = var.backend_services
    content {
      name            = path_matcher.key
      default_service = google_compute_backend_service.service_backend[path_matcher.key].id
    }
  }
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
