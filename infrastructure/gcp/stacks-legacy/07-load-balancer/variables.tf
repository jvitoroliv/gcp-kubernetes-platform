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
  description = "List of domains for the managed SSL certificate"
  type        = list(string)
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service to route traffic to"
  type        = string
}

variable "port" {
  description = "Port for HTTPS traffic"
  type        = number
  default     = 443
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
