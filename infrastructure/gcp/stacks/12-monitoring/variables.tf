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
  default     = "us-east1"
}

# -----------------------------------------------------------------------------
# GCS CONFIGURATION
# -----------------------------------------------------------------------------

variable "gcs_location" {
  description = "GCS bucket location (e.g. US-EAST1 for nonprod, SOUTHAMERICA-EAST1 for prd)"
  type        = string
  default     = "US-EAST1"
}

# -----------------------------------------------------------------------------
# GKE CLUSTER (for Workload Identity)
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "GKE cluster name (used for Workload Identity binding)"
  type        = string
}

# -----------------------------------------------------------------------------
# KUBERNETES NAMESPACE CONFIGURATION
# -----------------------------------------------------------------------------

variable "loki_namespace" {
  description = "Kubernetes namespace where Loki is deployed"
  type        = string
  default     = "monitoring"
}

variable "tempo_namespace" {
  description = "Kubernetes namespace where Tempo is deployed"
  type        = string
  default     = "monitoring"
}

# -----------------------------------------------------------------------------
# LABELS
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
