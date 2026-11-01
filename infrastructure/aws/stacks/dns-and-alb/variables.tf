variable "assume_role_arn" {
  description = "ARN of the IAM role to assume for cross-account access"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region for DNS and ALB resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, stg, live)"
  type        = string
}

variable "domain_name" {
  description = "Base domain name for the environment"
  type        = string
}

variable "create_hosted_zone" {
  description = "Create a new Route53 hosted zone (set false if zone already exists)"
  type        = bool
  default     = true
}

variable "hosted_zone_id" {
  description = "Existing Route53 hosted zone ID (required if create_hosted_zone = false)"
  type        = string
  default     = ""
}

variable "create_wildcard_certificate" {
  description = "Create ACM certificate for wildcard domain"
  type        = bool
  default     = true
}

variable "certificate_validation_method" {
  description = "Certificate validation method (DNS or EMAIL)"
  type        = string
  default     = "DNS"

  validation {
    condition     = contains(["DNS", "EMAIL"], var.certificate_validation_method)
    error_message = "Certificate validation method must be DNS or EMAIL."
  }
}

variable "certificate_subject_alternative_names" {
  description = "Additional domains for the certificate"
  type        = list(string)
  default     = []
}

variable "create_shared_alb" {
  description = "Create shared Application Load Balancer"
  type        = bool
  default     = true
}

variable "alb_scheme" {
  description = "ALB scheme (internet-facing or internal)"
  type        = string
  default     = "internet-facing"

  validation {
    condition     = contains(["internet-facing", "internal"], var.alb_scheme)
    error_message = "ALB scheme must be internet-facing or internal."
  }
}

variable "alb_type" {
  description = "ALB type (application or network)"
  type        = string
  default     = "application"

  validation {
    condition     = contains(["application", "network"], var.alb_type)
    error_message = "ALB type must be application or network."
  }
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB (recommended for production)"
  type        = bool
  default     = false
}

variable "enable_access_logs" {
  description = "Enable ALB access logs"
  type        = bool
  default     = true
}

variable "access_logs_retention_days" {
  description = "ALB access logs retention period (days)"
  type        = number
  default     = 3
}

variable "idle_timeout" {
  description = "ALB idle timeout in seconds"
  type        = number
  default     = 60
}

variable "enable_http2" {
  description = "Enable HTTP/2 on ALB"
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Enable AWS WAF for ALB"
  type        = bool
  default     = false
}

variable "default_target_group_config" {
  description = "Default target group configuration for ALB"
  type = object({
    port                 = number
    protocol             = string
    target_type          = string
    deregistration_delay = number
    health_check = object({
      enabled             = bool
      healthy_threshold   = number
      unhealthy_threshold = number
      timeout             = number
      interval            = number
      path                = string
      matcher             = string
      port                = string
      protocol            = string
    })
  })

  default = {
    port                 = 80
    protocol             = "HTTP"
    target_type          = "ip"
    deregistration_delay = 30
    health_check = {
      enabled             = true
      healthy_threshold   = 2
      unhealthy_threshold = 3
      timeout             = 5
      interval            = 30
      path                = "/health"
      matcher             = "200"
      port                = "traffic-port"
      protocol            = "HTTP"
    }
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Data source inputs (these should be provided via data sources in main.tf)
variable "vpc_id" {
  description = "VPC ID where ALB will be created (will be fetched via data source if not provided)"
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB (will be fetched via data source if not provided)"
  type        = list(string)
  default     = []
}