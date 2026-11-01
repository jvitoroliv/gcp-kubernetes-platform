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

variable "instance_name" {
  description = "Name of the compute instance"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the instance"
  type        = string
}

variable "zone" {
  description = "Zone for the instance"
  type        = string
}

variable "boot_disk" {
  description = "Boot disk configuration"
  type = object({
    image       = string
    size        = optional(number, 50)
    type        = optional(string, "pd-balanced")
    auto_delete = optional(bool, true)
  })
}

variable "network" {
  description = "VPC network self_link"
  type        = string
}

variable "subnetwork" {
  description = "Subnetwork self_link"
  type        = string
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Network tags for firewall rules"
  type        = list(string)
  default     = []
}

variable "service_account" {
  description = "Service account configuration"
  type = object({
    email  = string
    scopes = list(string)
  })
  default = null
}

variable "startup_script" {
  description = "Startup script content"
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
