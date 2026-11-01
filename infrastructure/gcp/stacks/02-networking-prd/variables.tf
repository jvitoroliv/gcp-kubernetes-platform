# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "southamerica-east1"
}

# -----------------------------------------------------------------------------
# VPC CONFIGURATION
# -----------------------------------------------------------------------------

variable "vpc_routing_mode" {
  description = "VPC routing mode: REGIONAL or GLOBAL"
  type        = string
  default     = "REGIONAL"
}

# -----------------------------------------------------------------------------
# WORKLOADS SUBNET CONFIGURATION
# -----------------------------------------------------------------------------

variable "workloads_subnet_cidr" {
  description = "Primary CIDR range for workloads subnet"
  type        = string
  default     = "10.100.0.0/20"
}

variable "workloads_pods_cidr" {
  description = "Secondary CIDR range for workloads GKE pods"
  type        = string
  default     = "10.104.0.0/14"
}

variable "workloads_services_cidr" {
  description = "Secondary CIDR range for workloads GKE services"
  type        = string
  default     = "10.108.0.0/20"
}

variable "workloads_master_cidr" {
  description = "CIDR range for workloads GKE master nodes (must be /28)"
  type        = string
  default     = "172.16.0.0/28"
}

# -----------------------------------------------------------------------------
# RUNNERS SUBNET CONFIGURATION
# -----------------------------------------------------------------------------

variable "runners_subnet_cidr" {
  description = "Primary CIDR range for runners subnet"
  type        = string
  default     = "10.112.0.0/20"
}

variable "runners_pods_cidr" {
  description = "Secondary CIDR range for runners GKE pods"
  type        = string
  default     = "10.116.0.0/14"
}

variable "runners_services_cidr" {
  description = "Secondary CIDR range for runners GKE services"
  type        = string
  default     = "10.120.0.0/20"
}

variable "runners_master_cidr" {
  description = "CIDR range for runners GKE master nodes (must be /28)"
  type        = string
  default     = "172.16.1.0/28"
}

# -----------------------------------------------------------------------------
# VPN CONFIGURATION
# -----------------------------------------------------------------------------

variable "vpn_cidr_ranges" {
  description = "CIDR ranges for VPN/on-premises network access"
  type        = list(string)
  default     = ["10.0.0.0/24"]
}

# -----------------------------------------------------------------------------
# CLOUD NAT CONFIGURATION
# -----------------------------------------------------------------------------

variable "nat_min_ports_per_vm" {
  description = "Minimum number of ports per VM for NAT"
  type        = number
  default     = 2048
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
# VPC FLOW LOGS
# -----------------------------------------------------------------------------

variable "enable_flow_logs" {
  description = "Enable VPC flow logs on subnets"
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
