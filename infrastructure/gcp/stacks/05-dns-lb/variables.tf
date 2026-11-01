# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stg, prd)"
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prd", "nonprod"], var.environment)
    error_message = "Environment must be one of: dev, stg, prd, nonprod"
  }
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "southamerica-east1"
}

# -----------------------------------------------------------------------------
# DNS CONFIGURATION
# -----------------------------------------------------------------------------

variable "dns_zones" {
  description = "Map of DNS zones to create"
  type = map(object({
    dns_name    = string
    description = optional(string, "")
    visibility  = optional(string, "public")
    dnssec      = optional(bool, true)
    # For private zones, specify VPC network URLs
    private_visibility_config = optional(object({
      networks = list(object({
        network_url = string
      }))
    }), null)
  }))
  default = {}
}

variable "dns_records" {
  description = "Map of DNS records to create"
  type = map(object({
    zone_name = string
    name      = string
    type      = string
    ttl       = optional(number, 300)
    rrdatas   = list(string)
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# GLOBAL LOAD BALANCER CONFIGURATION
# -----------------------------------------------------------------------------

variable "enable_global_lb" {
  description = "Enable Global HTTP(S) Load Balancer"
  type        = bool
  default     = true
}

variable "lb_name" {
  description = "Name prefix for load balancer resources"
  type        = string
  default     = ""
}

variable "ssl_domains" {
  description = "List of domains for Google-managed SSL certificates"
  type        = list(string)
  default     = []
}

variable "enable_cdn" {
  description = "Enable Cloud CDN on the load balancer"
  type        = bool
  default     = false
}

variable "cdn_cache_mode" {
  description = "CDN cache mode: CACHE_ALL_STATIC, USE_ORIGIN_HEADERS, FORCE_CACHE_ALL"
  type        = string
  default     = "CACHE_ALL_STATIC"
}

variable "cdn_default_ttl" {
  description = "Default CDN TTL in seconds"
  type        = number
  default     = 3600
}

# -----------------------------------------------------------------------------
# BACKEND SERVICES CONFIGURATION
# -----------------------------------------------------------------------------

variable "backend_services" {
  description = "Map of backend services to create"
  type = map(object({
    description         = optional(string, "")
    protocol            = optional(string, "HTTP")
    port_name           = optional(string, "http")
    timeout_sec         = optional(number, 30)
    enable_cdn          = optional(bool, false)
    health_check_path   = optional(string, "/health")
    health_check_port   = optional(number, 80)
    connection_draining = optional(number, 300)
    security_policy     = optional(string, null)
  }))
  default = {
    default = {
      description       = "Default backend service"
      protocol          = "HTTP"
      port_name         = "http"
      timeout_sec       = 30
      health_check_path = "/health"
      health_check_port = 80
    }
  }
}

# -----------------------------------------------------------------------------
# URL MAP / ROUTING CONFIGURATION
# -----------------------------------------------------------------------------

variable "url_map_default_service" {
  description = "Default backend service for the URL map"
  type        = string
  default     = "default"
}

variable "host_rules" {
  description = "Host-based routing rules"
  type = list(object({
    hosts        = list(string)
    path_matcher = string
  }))
  default = []
}

variable "path_matchers" {
  description = "Path matcher configurations"
  type = map(object({
    default_service = string
    path_rules = optional(list(object({
      paths   = list(string)
      service = string
    })), [])
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# SECURITY CONFIGURATION
# -----------------------------------------------------------------------------

variable "enable_cloud_armor" {
  description = "Enable Cloud Armor security policy"
  type        = bool
  default     = false
}

variable "cloud_armor_rules" {
  description = "Cloud Armor security rules"
  type = list(object({
    action      = string
    priority    = number
    description = optional(string, "")
    expression  = optional(string, null)
    src_ranges  = optional(list(string), null)
  }))
  default = []
}

# -----------------------------------------------------------------------------
# GATEWAY API STATIC IP
# -----------------------------------------------------------------------------

variable "enable_gateway_ip" {
  description = "Enable static IP for GKE Gateway API"
  type        = bool
  default     = false
}

variable "gateway_ip_name" {
  description = "Name for the Gateway static IP"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# APPLICATION LOAD BALANCER (AWS ALB Equivalent)
# -----------------------------------------------------------------------------

variable "enable_alb" {
  description = "Enable Application Load Balancer (AWS ALB equivalent) with hostname routing"
  type        = bool
  default     = false
}

variable "alb_ssl_domains" {
  description = "Domains for ALB Google-managed certificate (e.g., ['dev-gameplatform.example.com', '*.dev-gameplatform.example.com'])"
  type        = list(string)
  default     = []
}

variable "alb_default_service" {
  description = "Default backend service for the ALB URL map"
  type        = string
  default     = "lobby"
}

variable "alb_services" {
  description = "Map of services for ALB with hostname-based routing (port 443)"
  type = map(object({
    hostnames         = list(string)
    backend_port      = number
    health_check_path = optional(string, "/health")
    timeout_sec       = optional(number, 30)
    description       = optional(string, "")
    neg_self_links    = optional(list(string), null)
  }))
  default = {}
}

variable "alb_tcp_services" {
  description = "Map of services for TCP Proxy with custom ports (same IP as ALB)"
  type = map(object({
    port           = number
    backend_port   = number
    timeout_sec    = optional(number, 30)
    description    = optional(string, "")
    neg_self_links = optional(list(string), null)
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# SSL PROXY LOAD BALANCER (Custom Ports) - LEGACY
# -----------------------------------------------------------------------------

variable "enable_ssl_proxy" {
  description = "Enable SSL Proxy Load Balancer for custom port TLS termination (legacy)"
  type        = bool
  default     = false
}

variable "ssl_proxy_certificate_domains" {
  description = "Domains for SSL Proxy Google-managed certificate (e.g., ['*.dev-gameplatform.example.com'])"
  type        = list(string)
  default     = []
}

variable "ssl_proxy_external_certificate" {
  description = "External SSL certificate ID to use for SSL Proxy (e.g., GKE ManagedCertificate). When set, ssl_proxy_certificate_domains is ignored."
  type        = string
  default     = ""
}

variable "ssl_proxy_services" {
  description = "Map of services for SSL Proxy Load Balancer with custom ports"
  type = map(object({
    port              = number
    backend_port      = number
    health_check_path = optional(string, "/health")
    timeout_sec       = optional(number, 30)
    description       = optional(string, "")
    neg_self_links    = optional(list(string), null)
  }))
  default = {}
}

variable "ssl_proxy_neg_zones" {
  description = "Zones for Network Endpoint Groups (NEGs)"
  type        = list(string)
  default     = ["us-east1-b", "us-east1-c", "us-east1-d"]
}

variable "gke_cluster_name" {
  description = "GKE cluster name for NEG backend"
  type        = string
  default     = ""
}

variable "gke_namespace" {
  description = "Kubernetes namespace for services"
  type        = string
  default     = "gameplatform-dev"
}

# -----------------------------------------------------------------------------
# REGIONAL INGRESS IP (for GKE nginx-ingress LoadBalancer)
# -----------------------------------------------------------------------------

variable "enable_regional_ingress_ip" {
  description = "Enable regional static IP for GKE nginx-ingress LoadBalancer"
  type        = bool
  default     = false
}

variable "regional_ingress_ip_name" {
  description = "Name for the regional ingress static IP"
  type        = string
  default     = ""
}

variable "regional_ingress_ip_address" {
  description = "Specific IP address to use (for importing existing IPs)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# LABELS
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
