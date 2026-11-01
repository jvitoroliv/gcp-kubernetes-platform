# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stg, prd, nonprod)"
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
# NETWORKING (from 02-networking stack outputs)
# -----------------------------------------------------------------------------

variable "vpc_self_link" {
  description = "VPC network self link"
  type        = string
}

variable "vpc_name" {
  description = "VPC network name"
  type        = string
}

variable "subnet_self_link" {
  description = "Subnet self link"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary range for pods"
  type        = string
  default     = "pods"
}

variable "services_range_name" {
  description = "Name of the secondary range for services"
  type        = string
  default     = "services"
}

variable "master_ipv4_cidr" {
  description = "CIDR range for GKE master nodes (must not overlap with other clusters)"
  type        = string
  default     = "172.16.1.0/28"  # Different from main cluster (172.16.0.0/28)
}

# -----------------------------------------------------------------------------
# GKE CLUSTER CONFIGURATION
# -----------------------------------------------------------------------------

variable "release_channel" {
  description = "GKE release channel: RAPID, REGULAR, STABLE"
  type        = string
  default     = "REGULAR"
}

variable "master_authorized_networks" {
  description = "CIDR blocks allowed to access the master endpoint"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "deletion_protection" {
  description = "Enable deletion protection for the cluster"
  type        = bool
  default     = false  # CI cluster can be recreated easily
}

# -----------------------------------------------------------------------------
# NODE POOL: GKE NODE SERVICE ACCOUNT
# -----------------------------------------------------------------------------

variable "gke_node_service_account" {
  description = "Service account email for GKE nodes"
  type        = string
}

# -----------------------------------------------------------------------------
# NODE POOL: HEAVY RUNNERS
# -----------------------------------------------------------------------------

variable "heavy_pool_machine_type" {
  description = "Machine type for heavy runner nodes"
  type        = string
  default     = "e2-standard-8"  # 8 vCPU, 32GB RAM
}

variable "heavy_pool_min_nodes" {
  description = "Minimum number of heavy runner nodes"
  type        = number
  default     = 0  # Scale to zero when idle
}

variable "heavy_pool_max_nodes" {
  description = "Maximum number of heavy runner nodes"
  type        = number
  default     = 5
}

variable "heavy_pool_disk_size" {
  description = "Disk size in GB for heavy runner nodes"
  type        = number
  default     = 100  # More space for Docker images/layers
}

# -----------------------------------------------------------------------------
# NODE POOL: INFRA (ArgoCD, ESO, ARC Controller)
# Pool for infrastructure workloads - always running, no taints
# -----------------------------------------------------------------------------

variable "infra_pool_machine_type" {
  description = "Machine type for infra node"
  type        = string
  default     = "e2-medium"  # 2 vCPU, 4GB RAM - sufficient for ArgoCD + ESO + ARC controller
}

variable "infra_pool_min_nodes" {
  description = "Minimum number of infra nodes (should be 1)"
  type        = number
  default     = 1  # Always keep 1 node for infra workloads
}

variable "infra_pool_max_nodes" {
  description = "Maximum number of infra nodes"
  type        = number
  default     = 2  # Allow scaling if needed
}

variable "infra_pool_disk_size" {
  description = "Disk size in GB for infra node"
  type        = number
  default     = 30  # Small disk for infra
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
  default     = "04:00"  # Different from main cluster
}

# -----------------------------------------------------------------------------
# LABELS
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
