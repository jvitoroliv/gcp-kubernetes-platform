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

variable "private_service_connection_peering" {
  description = "Private service connection peering name"
  type        = string
}

# -----------------------------------------------------------------------------
# CLOUD SQL CONFIGURATION
# -----------------------------------------------------------------------------

variable "instance_name" {
  description = "Cloud SQL instance name (defaults to gameplatform-{environment}-postgres)"
  type        = string
  default     = ""
}

variable "database_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-custom-2-8192" # 2 vCPUs, 8GB RAM
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 100
}

variable "disk_type" {
  description = "Disk type: PD_SSD or PD_HDD"
  type        = string
  default     = "PD_SSD"
}

variable "disk_autoresize" {
  description = "Enable disk auto-resize"
  type        = bool
  default     = true
}

variable "disk_autoresize_limit" {
  description = "Maximum disk size for auto-resize (0 = unlimited)"
  type        = number
  default     = 500
}

# -----------------------------------------------------------------------------
# HIGH AVAILABILITY
# -----------------------------------------------------------------------------

variable "availability_type" {
  description = "Availability type: REGIONAL (HA) or ZONAL"
  type        = string
  default     = "REGIONAL"
}

# -----------------------------------------------------------------------------
# BACKUP CONFIGURATION
# -----------------------------------------------------------------------------

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_start_time" {
  description = "Start time for backup window (HH:MM format, UTC)"
  type        = string
  default     = "03:00"
}

variable "backup_location" {
  description = "Location for backups (default: same region)"
  type        = string
  default     = ""
}

variable "point_in_time_recovery_enabled" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "transaction_log_retention_days" {
  description = "Number of days to retain transaction logs"
  type        = number
  default     = 7
}

variable "retained_backups" {
  description = "Number of backups to retain"
  type        = number
  default     = 7
}

# -----------------------------------------------------------------------------
# MAINTENANCE WINDOW
# -----------------------------------------------------------------------------

variable "maintenance_window_day" {
  description = "Day of week for maintenance (1=Monday, 7=Sunday)"
  type        = number
  default     = 7
}

variable "maintenance_window_hour" {
  description = "Hour for maintenance (0-23 UTC)"
  type        = number
  default     = 3
}

variable "maintenance_window_update_track" {
  description = "Maintenance update track: canary, stable, or week5"
  type        = string
  default     = "stable"
}

# -----------------------------------------------------------------------------
# DATABASE CONFIGURATION
# -----------------------------------------------------------------------------

variable "databases" {
  description = "Map of databases to create"
  type = map(object({
    charset   = optional(string, "UTF8")
    collation = optional(string, "en_US.UTF8")
  }))
  default = {
    nakama = {
      charset   = "UTF8"
      collation = "en_US.UTF8"
    }
    lobby = {
      charset   = "UTF8"
      collation = "en_US.UTF8"
    }
  }
}

variable "users" {
  description = "Map of database users to create"
  type = map(object({
    type     = optional(string, "BUILT_IN")
    password = optional(string, null) # If null, will be auto-generated
  }))
  default = {
    nakama = {}
    lobby  = {}
  }
}

# -----------------------------------------------------------------------------
# DATABASE FLAGS
# -----------------------------------------------------------------------------

variable "database_flags" {
  description = "Database flags to set on the instance"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "max_connections"
      value = "500"
    },
    {
      name  = "log_checkpoints"
      value = "on"
    },
    {
      name  = "log_connections"
      value = "on"
    },
    {
      name  = "log_disconnections"
      value = "on"
    },
    {
      name  = "log_lock_waits"
      value = "on"
    }
  ]
}

# -----------------------------------------------------------------------------
# INSIGHTS
# -----------------------------------------------------------------------------

variable "insights_config" {
  description = "Query insights configuration"
  type = object({
    query_insights_enabled  = bool
    query_string_length     = optional(number, 1024)
    record_application_tags = optional(bool, true)
    record_client_address   = optional(bool, true)
  })
  default = {
    query_insights_enabled  = true
    query_string_length     = 1024
    record_application_tags = true
    record_client_address   = true
  }
}

# -----------------------------------------------------------------------------
# DELETION PROTECTION
# -----------------------------------------------------------------------------

variable "deletion_protection" {
  description = "Enable deletion protection"
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
