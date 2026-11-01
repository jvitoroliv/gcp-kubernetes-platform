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

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "southamerica-east1"
}

# -----------------------------------------------------------------------------
# VPC CONFIGURATION
# -----------------------------------------------------------------------------

variable "vpc_name" {
  description = "Name of the VPC (defaults to gameplatform-{environment}-vpc)"
  type        = string
  default     = ""
}

variable "vpc_routing_mode" {
  description = "VPC routing mode: REGIONAL or GLOBAL"
  type        = string
  default     = "REGIONAL"
}

# -----------------------------------------------------------------------------
# SUBNET CONFIGURATION
# -----------------------------------------------------------------------------

variable "subnet_cidr" {
  description = "Primary CIDR range for the main subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE pods"
  type        = string
  default     = "10.16.0.0/14"
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE services"
  type        = string
  default     = "10.20.0.0/20"
}

variable "master_ipv4_cidr" {
  description = "CIDR range for GKE master nodes (must be /28)"
  type        = string
  default     = "172.16.0.0/28"
}

# -----------------------------------------------------------------------------
# RUNNERS CLUSTER CONFIGURATION (Optional secondary ranges)
# -----------------------------------------------------------------------------

variable "enable_runners_ranges" {
  description = "Enable secondary IP ranges for runners GKE cluster"
  type        = bool
  default     = false
}

variable "pods_runners_cidr" {
  description = "Secondary CIDR range for runners GKE pods"
  type        = string
  default     = "10.24.0.0/14"  # Non-overlapping with main pods (10.16.0.0/14)
}

variable "services_runners_cidr" {
  description = "Secondary CIDR range for runners GKE services"
  type        = string
  default     = "10.28.0.0/20"  # Non-overlapping with main services (10.20.0.0/20)
}

variable "master_runners_ipv4_cidr" {
  description = "CIDR range for runners GKE master nodes (must be /28)"
  type        = string
  default     = "172.16.1.0/28"  # Non-overlapping with main master (172.16.0.0/28)
}

# -----------------------------------------------------------------------------
# CLOUD NAT CONFIGURATION
# -----------------------------------------------------------------------------

variable "enable_cloud_nat" {
  description = "Enable Cloud NAT for private GKE nodes"
  type        = bool
  default     = true
}

variable "nat_min_ports_per_vm" {
  description = "Minimum number of ports per VM for NAT"
  type        = number
  default     = 64
}

variable "nat_enable_logging" {
  description = "Enable Cloud NAT logging"
  type        = bool
  default     = true
}

variable "nat_log_filter" {
  description = "NAT log filter: ERRORS_ONLY, TRANSLATIONS_ONLY, ALL"
  type        = string
  default     = "ERRORS_ONLY"
}

# -----------------------------------------------------------------------------
# FIREWALL CONFIGURATION
# -----------------------------------------------------------------------------

variable "enable_default_firewall_rules" {
  description = "Create default firewall rules (internal, health checks)"
  type        = bool
  default     = true
}

variable "allowed_external_cidrs" {
  description = "CIDR blocks allowed to access the load balancer"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# VPC FLOW LOGS
# -----------------------------------------------------------------------------

variable "enable_flow_logs" {
  description = "Enable VPC flow logs on the subnet"
  type        = bool
  default     = true
}

variable "flow_logs_sampling" {
  description = "Flow logs sampling rate (0.0 to 1.0)"
  type        = number
  default     = 0.5
}

variable "flow_logs_interval" {
  description = "Flow logs aggregation interval"
  type        = string
  default     = "INTERVAL_5_SEC"
}

# -----------------------------------------------------------------------------
# LABELS
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
