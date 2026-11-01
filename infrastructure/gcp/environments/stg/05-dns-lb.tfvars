# =============================================================================
# STG ENVIRONMENT - DNS AND LOAD BALANCER STACK
# NOTE: Stg has SAME configuration as Prd for parity testing
# =============================================================================

project_id  = "project-nonprod-env"
environment = "stg"
region      = "us-east1"

# DNS Zones
dns_zones = {
  project-nonprod-env = {
    dns_name    = "stg.gameplatform.example.com."
    description = "GamePlatform stg environment DNS zone"
    visibility  = "public"
    dnssec      = true # SAME AS PRD
  }
}

# Global Load Balancer
enable_global_lb = true

# SSL Domains
ssl_domains = [
  "stg.gameplatform.example.com",
  "api.stg.gameplatform.example.com",
  "game.stg.gameplatform.example.com",
]

# CDN - SAME AS PRD
enable_cdn      = true
cdn_cache_mode  = "CACHE_ALL_STATIC"
cdn_default_ttl = 3600

# Backend Services - SAME AS PRD
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
    hosts        = ["api.stg.gameplatform.example.com"]
    path_matcher = "api"
  },
  {
    hosts        = ["game.stg.gameplatform.example.com"]
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

# Cloud Armor - SAME AS PRD
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
  owner       = "infrastructure-team"
  cost_center = "stg"
}
