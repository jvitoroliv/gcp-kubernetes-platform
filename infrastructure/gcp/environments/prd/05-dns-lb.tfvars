# =============================================================================
# PRD (PRODUCTION) ENVIRONMENT - DNS AND LOAD BALANCER STACK
# =============================================================================

project_id  = "project-prd-env"
environment = "prd"
region      = "southamerica-east1"

# DNS Zones
dns_zones = {
  gameplatform-dns = {
    dns_name    = "gameplatform.example.com."
    description = "GamePlatform production DNS zone"
    visibility  = "public"
    dnssec      = true
  }
}

# Global Load Balancer
enable_global_lb = true

# SSL Domains
ssl_domains = [
  "gameplatform.example.com",
  "www.gameplatform.example.com",
  "api.gameplatform.example.com",
  "game.gameplatform.example.com",
]

# CDN - Enabled for production
enable_cdn      = true
cdn_cache_mode  = "CACHE_ALL_STATIC"
cdn_default_ttl = 3600

# Backend Services
backend_services = {
  default = {
    description         = "Default backend service"
    protocol            = "HTTP"
    port_name           = "http"
    timeout_sec         = 30
    health_check_path   = "/health"
    health_check_port   = 80
    enable_cdn          = true
    connection_draining = 300
  }
  api = {
    description         = "API backend service"
    protocol            = "HTTP"
    port_name           = "http"
    timeout_sec         = 60
    health_check_path   = "/healthz"
    health_check_port   = 80
    enable_cdn          = false
    connection_draining = 300
  }
  game = {
    description         = "Game server backend service"
    protocol            = "HTTP"
    port_name           = "http"
    timeout_sec         = 3600 # Long timeout for WebSocket connections
    health_check_path   = "/healthcheck"
    health_check_port   = 7350
    enable_cdn          = false
    connection_draining = 60
  }
}

url_map_default_service = "default"

host_rules = [
  {
    hosts        = ["api.gameplatform.example.com"]
    path_matcher = "api"
  },
  {
    hosts        = ["game.gameplatform.example.com"]
    path_matcher = "game"
  }
]

path_matchers = {
  api = {
    default_service = "api"
  }
  game = {
    default_service = "game"
  }
}

# Cloud Armor - Enabled for production
enable_cloud_armor = true
cloud_armor_rules = [
  {
    action      = "deny(403)"
    priority    = 1000
    description = "Block known bad IPs"
    expression  = "origin.region_code == 'XX'"
  },
  {
    action      = "throttle"
    priority    = 2000
    description = "Rate limit requests"
    expression  = "true"
  }
]

labels = {
  owner              = "infrastructure-team"
  cost_center        = "production"
  data_classification = "confidential"
  compliance         = "required"
}
