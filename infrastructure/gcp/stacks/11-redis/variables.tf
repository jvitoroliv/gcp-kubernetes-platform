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

variable "vpc_id" {
  description = "VPC network ID (projects/PROJECT/global/networks/VPC_NAME)"
  type        = string
}

variable "private_service_connection_peering" {
  description = "Private service connection peering name (dependency marker)"
  type        = string
}

# -----------------------------------------------------------------------------
# REDIS CONFIGURATION
# -----------------------------------------------------------------------------

variable "instance_name" {
  description = "Redis instance name (defaults to gameplatform-{environment}-redis)"
  type        = string
  default     = ""
}

variable "redis_version" {
  description = "Redis version (REDIS_7_0, REDIS_6_X, etc.)"
  type        = string
  default     = "REDIS_7_0"
}

variable "tier" {
  description = "Service tier: BASIC (no replication) or STANDARD_HA (high availability)"
  type        = string
  default     = "BASIC"

  validation {
    condition     = contains(["BASIC", "STANDARD_HA"], var.tier)
    error_message = "Tier must be either BASIC or STANDARD_HA"
  }
}

variable "memory_size_gb" {
  description = "Memory size in GB (1-300)"
  type        = number
  default     = 1

  validation {
    condition     = var.memory_size_gb >= 1 && var.memory_size_gb <= 300
    error_message = "Memory size must be between 1 and 300 GB"
  }
}

variable "redis_configs" {
  description = "Redis configuration parameters"
  type        = map(string)
  default = {
    maxmemory-policy = "allkeys-lru"
  }
}

# -----------------------------------------------------------------------------
# MAINTENANCE WINDOW
# -----------------------------------------------------------------------------

variable "maintenance_window_day" {
  description = "Day of week for maintenance (MONDAY, TUESDAY, etc.) - null to disable"
  type        = string
  default     = "SUNDAY"
}

variable "maintenance_window_hour" {
  description = "Hour for maintenance (0-23 UTC)"
  type        = number
  default     = 3
}

# -----------------------------------------------------------------------------
# LABELS
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
