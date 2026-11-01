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
# NETWORKING (from 02-networking stack outputs)
# -----------------------------------------------------------------------------

variable "vpc_self_link" {
  description = "VPC network self link"
  type        = string
}

variable "subnet_self_link" {
  description = "Subnet self link"
  type        = string
}

variable "master_ipv4_cidr" {
  description = "CIDR range for GKE master nodes"
  type        = string
  default     = "172.16.0.0/28"
}

# -----------------------------------------------------------------------------
# GKE CLUSTER CONFIGURATION
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the GKE cluster (defaults to gameplatform-{environment})"
  type        = string
  default     = ""
}

variable "release_channel" {
  description = "GKE release channel: RAPID, REGULAR, STABLE"
  type        = string
  default     = "REGULAR"
}

variable "enable_private_nodes" {
  description = "Enable private nodes (no public IPs)"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint (master accessible only from VPC)"
  type        = bool
  default     = false
}

variable "master_global_access" {
  description = "Enable master global access (from any region)"
  type        = bool
  default     = true
}

variable "master_authorized_networks" {
  description = "CIDR blocks allowed to access the master endpoint"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity for GKE"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection for the cluster"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# NODE POOL CONFIGURATION
# -----------------------------------------------------------------------------

variable "gke_node_service_account" {
  description = "Service account email for GKE nodes"
  type        = string
}

variable "node_pools" {
  description = "Map of node pools to create"
  type = map(object({
    machine_type   = string
    min_node_count = number
    max_node_count = number
    disk_size_gb   = optional(number, 100)
    disk_type      = optional(string, "pd-standard")
    preemptible    = optional(bool, false)
    spot           = optional(bool, false)
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = {
    general = {
      machine_type   = "e2-standard-4"
      min_node_count = 1
      max_node_count = 5
      disk_size_gb   = 100
      disk_type      = "pd-standard"
      preemptible    = false
      spot           = false
    }
  }
}

# -----------------------------------------------------------------------------
# NODE MANAGEMENT
# -----------------------------------------------------------------------------

variable "node_auto_upgrade" {
  description = "Enable auto-upgrade for node pools"
  type        = bool
  default     = false
}

variable "node_auto_repair" {
  description = "Enable auto-repair for node pools"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# MAINTENANCE WINDOW
# -----------------------------------------------------------------------------

variable "maintenance_start_time" {
  description = "Start time for daily maintenance window (UTC)"
  type        = string
  default     = "03:00"
}

# -----------------------------------------------------------------------------
# MONITORING AND LOGGING
# -----------------------------------------------------------------------------

variable "monitoring_components" {
  description = "GKE monitoring components to enable"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

variable "logging_components" {
  description = "GKE logging components to enable"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

variable "enable_managed_prometheus" {
  description = "Enable Google Cloud Managed Service for Prometheus"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# GATEWAY API
# -----------------------------------------------------------------------------

variable "gateway_api_channel" {
  description = "Gateway API channel: CHANNEL_DISABLED, CHANNEL_EXPERIMENTAL, or CHANNEL_STANDARD"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# ADDONS
# -----------------------------------------------------------------------------

variable "enable_http_load_balancing" {
  description = "Enable HTTP Load Balancing addon"
  type        = bool
  default     = true
}

variable "enable_horizontal_pod_autoscaling" {
  description = "Enable Horizontal Pod Autoscaling addon"
  type        = bool
  default     = true
}

variable "enable_gce_persistent_disk_csi_driver" {
  description = "Enable GCE Persistent Disk CSI Driver addon"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# LABELS
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
