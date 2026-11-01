# -----------------------------------------------------------------------------
# VARIABLES
# -----------------------------------------------------------------------------

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

variable "lb_name" {
  description = "Name prefix for load balancer resources"
  type        = string
}

variable "ssl_domains" {
  description = "List of domains for SSL certificate"
  type        = list(string)
}

variable "vm_zone" {
  description = "Zone where the VM is located"
  type        = string
}

variable "vm_self_link" {
  description = "Self link of the VM instance"
  type        = string
}

variable "backend_services" {
  description = "Map of backend services with their configuration"
  type = map(object({
    port  = number
    hosts = list(string)
  }))
}

variable "default_service" {
  description = "Default backend service name (used when no host matches)"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
