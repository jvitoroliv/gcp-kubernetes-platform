# =============================================================================
# DEV ENVIRONMENT - DNS AND LOAD BALANCER STACK
# =============================================================================

project_id  = "project-nonprod-env"
environment = "dev"
region      = "us-east1"

# DNS Zones
# NOTE: Public zone dev-gameplatform-dns is managed by Cloud Domains
dns_zones = {
  gameplatform-dev = {
    dns_name    = "dev-gameplatform.example.com."
    description = "GamePlatform dev environment DNS zone"
    visibility  = "public"
    dnssec      = false # Simplified for dev
  }
}

# Global Load Balancer
enable_global_lb = false # Using Internal LB via GKE Ingress

# SSL Domains
ssl_domains = [
  "dev-gameplatform.example.com",
  "api.dev-gameplatform.example.com",
]

# CDN - Disabled for dev
enable_cdn = false

# Backend Services
backend_services = {
  default = {
    description       = "Default backend service"
    protocol          = "HTTP"
    port_name         = "http"
    timeout_sec       = 30
    health_check_path = "/health"
    health_check_port = 80
    enable_cdn        = false
  }
  api = {
    description       = "API backend service"
    protocol          = "HTTP"
    port_name         = "http"
    timeout_sec       = 60
    health_check_path = "/healthz"
    health_check_port = 80
    enable_cdn        = false
  }
}

url_map_default_service = "default"

# Cloud Armor - Disabled for dev
enable_cloud_armor = false

labels = {
  owner       = "infrastructure-team"
  cost_center = "development"
}
