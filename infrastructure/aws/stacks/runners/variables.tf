variable "assume_role_arn" {
  description = "ARN of the IAM role to assume for cross-account access"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region for ECS runners/shared cluster"
  type        = string
  default     = "us-east-1"
}

variable "aws_region" {
  description = "AWS region for deployment (used by provider)"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, stg, live)"
  type        = string
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights on the cluster"
  type        = bool
  default     = true
}

variable "capacity_providers" {
  description = "Capacity providers to associate with the cluster"
  type        = list(string)
  default     = ["FARGATE", "FARGATE_SPOT"]
}

variable "capacity_provider_strategy" {
  description = "Optional default capacity provider strategy entries"
  type = list(object({
    capacity_provider = string
    weight            = optional(number)
    base              = optional(number)
  }))
  default = []
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

