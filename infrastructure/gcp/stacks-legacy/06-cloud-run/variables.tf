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

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
}

variable "description" {
  description = "Description of the service"
  type        = string
  default     = ""
}

variable "container" {
  description = "Container configuration"
  type = object({
    name  = string
    image = string
    port  = optional(number)
    env_vars = optional(list(object({
      name   = string
      value  = optional(string)
      secret = optional(object({
        secret  = string
        version = string
      }))
    })), [])
    resources = object({
      cpu               = string
      memory            = string
      cpu_idle          = optional(bool, true)
      startup_cpu_boost = optional(bool, false)
    })
  })
}

variable "min_instance_count" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_instance_count" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "service_account" {
  description = "Service account email for the Cloud Run service"
  type        = string
  default     = null
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated access"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
