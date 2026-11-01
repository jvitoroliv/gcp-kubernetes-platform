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

variable "dns_zones" {
  description = "Map of DNS zones to create"
  type = map(object({
    dns_name    = string
    description = string
    visibility  = string
  }))
  default = {}
}

variable "dns_records" {
  description = "Map of DNS records to create"
  type = map(object({
    zone    = string
    name    = string
    type    = string
    ttl     = number
    rrdatas = list(string)
  }))
  default = {}
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
