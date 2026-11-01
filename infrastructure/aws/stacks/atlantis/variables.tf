variable "assume_role_arn" {
  description = "ARN of the IAM role to assume for cross-account access"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region for Atlantis deployment"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stg, live)"
  type        = string
}

variable "atlantis_image" {
  description = "Atlantis Docker image"
  type        = string
  default     = "777777777772.dkr.ecr.sa-east-1.amazonaws.com/gameplatform-atlantis:v-1.0.0"
}

variable "atlantis_port" {
  description = "Port for Atlantis server"
  type        = number
  default     = 4141
}

variable "atlantis_cpu" {
  description = "CPU units for Atlantis ECS task"
  type        = number
  default     = 1024
}

variable "atlantis_memory" {
  description = "Memory in MB for Atlantis ECS task"
  type        = number
  default     = 2048
}

variable "atlantis_desired_count" {
  description = "Desired number of Atlantis tasks"
  type        = number
  default     = 1
}

variable "github_owner" {
  description = "GitHub organization/user name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for monorepo"
  type        = string
  default     = "gameplatform-shared-infrastructure"
}

variable "github_webhook_secret" {
  description = "GitHub webhook secret (will be stored in SSM)"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token (will be stored in SSM)"
  type        = string
  sensitive   = true
}

variable "atlantis_domain" {
  description = "Domain for Atlantis (e.g., atlantis.dev.gameplatform.click)"
  type        = string
}

variable "terraform_modules_repo" {
  description = "SSH URL for terraform modules repository"
  type        = string
  default     = "github.com/example-gamedev-org/gameplatform-terraform.git"
}

variable "enable_auto_scaling" {
  description = "Enable auto scaling for Atlantis ECS service"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum number of Atlantis tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of Atlantis tasks"
  type        = number
  default     = 3
}

variable "enable_access_logs" {
  description = "Enable ALB access logs for Atlantis"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 3
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}