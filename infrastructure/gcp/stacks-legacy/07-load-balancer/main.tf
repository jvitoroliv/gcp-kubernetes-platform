# -----------------------------------------------------------------------------
# LOAD BALANCER STACK - LEGACY
# Creates HTTPS Load Balancer for Cloud Run with managed SSL
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "load-balancer"
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

module "ssl_certificate" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/lb-ssl-certificate"

  name    = "${var.lb_name}-cert"
  project = var.project_id
  domains = var.ssl_domains

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# SERVERLESS NEG (Network Endpoint Group for Cloud Run)
# -----------------------------------------------------------------------------

resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "${var.lb_name}-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }
}

# -----------------------------------------------------------------------------
# BACKEND SERVICE
# -----------------------------------------------------------------------------

resource "google_compute_backend_service" "cloud_run_backend" {
  name        = "${var.lb_name}-backend"
  project     = var.project_id
  description = "Backend service for ${var.cloud_run_service_name}"

  protocol                        = "HTTPS"
  port_name                       = "http"
  timeout_sec                     = 30
  connection_draining_timeout_sec = 300
  load_balancing_scheme           = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg.id
  }

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
  default_service = google_compute_backend_service.cloud_run_backend.id
}

# -----------------------------------------------------------------------------
# HTTPS PROXY
# -----------------------------------------------------------------------------

resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "${var.lb_name}-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = [module.ssl_certificate.self_link]
}

# -----------------------------------------------------------------------------
# FORWARDING RULE (HTTPS on 443)
# -----------------------------------------------------------------------------

resource "google_compute_global_forwarding_rule" "https_rule" {
  name                  = "${var.lb_name}-https-rule"
  project               = var.project_id
  target                = google_compute_target_https_proxy.https_proxy.id
  port_range            = var.port
  ip_address            = google_compute_global_address.lb_ip.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# HTTP TO HTTPS REDIRECT (Optional)
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
