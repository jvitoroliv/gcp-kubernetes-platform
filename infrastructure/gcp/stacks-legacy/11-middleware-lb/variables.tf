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

variable "service_port" {
  description = "Port where the middleware service runs"
  type        = number
  default     = 3333
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
