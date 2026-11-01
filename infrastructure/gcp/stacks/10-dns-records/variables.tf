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
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "Environment must be one of: dev, stg, prd"
  }
}

# -----------------------------------------------------------------------------
# DNS ZONE CONFIGURATION (from 05-dns-lb stack)
# -----------------------------------------------------------------------------

variable "dns_zone_name" {
  description = "Cloud DNS managed zone name"
  type        = string
}

variable "dns_zone_dns_name" {
  description = "DNS zone domain name (e.g., gameplatform.example.com.)"
  type        = string
}

# -----------------------------------------------------------------------------
# LOAD BALANCER IP
# -----------------------------------------------------------------------------

variable "alb_ip_address" {
  description = "IP address of the Application Load Balancer"
  type        = string
}

# -----------------------------------------------------------------------------
# SERVICE SUBDOMAINS
# List of service subdomains that point to the ALB
# -----------------------------------------------------------------------------

variable "service_subdomains" {
  description = "List of service subdomains to create A records for"
  type        = list(string)
  default = [
    "aes",
    "afs",
    "ahsat",
    "ais",
    "ani-metrics",
    "aps",
    "lobby-backend",
    "nakama"
  ]
}

# -----------------------------------------------------------------------------
# LABELS
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
