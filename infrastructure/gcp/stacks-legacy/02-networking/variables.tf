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

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
}

variable "subnet_region" {
  description = "Region for the subnet"
  type        = string
}

variable "firewall_rules" {
  description = "Map of firewall rules to create"
  type = map(object({
    description        = string
    direction          = string
    priority           = number
    source_ranges      = optional(list(string), [])
    destination_ranges = optional(list(string), [])
    target_tags        = optional(list(string), [])
    source_tags        = optional(list(string), [])
    allow_rules = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    deny_rules = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
  }))
  default = {}
}

variable "create_nat" {
  description = "Whether to create Cloud NAT"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
