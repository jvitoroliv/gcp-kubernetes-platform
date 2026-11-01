variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "bucket_name" {
  description = "Name of the GCS bucket"
  type        = string
}

variable "bucket_location" {
  description = "Location of the GCS bucket"
  type        = string
}

variable "storage_class" {
  description = "Storage class for the bucket"
  type        = string
  default     = "STANDARD"
}

variable "versioning_enabled" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for the bucket"
  type = list(object({
    action = object({
      type          = string
      storage_class = optional(string)
    })
    condition = object({
      age                   = optional(number)
      created_before        = optional(string)
      num_newer_versions    = optional(number)
      matches_storage_class = optional(list(string))
    })
  }))
  default = []
}

variable "cors_config" {
  description = "CORS configuration for the bucket"
  type = object({
    origin          = list(string)
    method          = list(string)
    response_header = optional(list(string), [])
    max_age_seconds = optional(number, 3600)
  })
  default = null
}

variable "bucket_iam_members" {
  description = "List of IAM members for the bucket"
  type = list(object({
    role   = string
    member = string
  }))
  default = []
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
