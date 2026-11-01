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
# GCP APIs TO ENABLE
# -----------------------------------------------------------------------------

variable "enable_apis" {
  description = "List of GCP APIs to enable"
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "dns.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "certificatemanager.googleapis.com",
    "iap.googleapis.com",
    "redis.googleapis.com",
  ]
}

# -----------------------------------------------------------------------------
# SERVICE ACCOUNTS CONFIGURATION
# -----------------------------------------------------------------------------

variable "create_gke_service_account" {
  description = "Create service account for GKE nodes"
  type        = bool
  default     = true
}

variable "create_cloudsql_service_account" {
  description = "Create service account for Cloud SQL admin operations"
  type        = bool
  default     = true
}

variable "create_workload_identity_service_accounts" {
  description = "Map of workload identity service accounts to create"
  type = map(object({
    display_name = string
    description  = optional(string)
    roles        = optional(list(string), [])
    workload_identity_binding = optional(object({
      namespace           = string
      k8s_service_account = string
    }))
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# LABELS
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
