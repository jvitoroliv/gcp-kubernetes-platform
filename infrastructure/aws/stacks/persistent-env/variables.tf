variable "region" {
  description = "AWS region for networking resources"
  type        = string
  default     = "us-east-1"
}

variable "pr_number" {
  description = "Pull Request number for environment identification"
  type        = string
}

variable "git_sha" {
  description = "Git commit SHA for tracking deployments"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Base domain for environments"
  type        = string
  default     = "dev.gameplatform.click"
}

variable "environment" {
  description = "Environment name (dev, stg, live)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "container_images" {
  description = "Container images for services"
  type = object({
    nakama        = string
    afs           = string
    ahsat         = string
    lobby         = string
    aes           = string
    ais           = string
    aps           = string
    lobby_backend = string
  })
  default = {
    nakama        = ""
    afs           = ""
    ahsat         = ""
    lobby         = ""
    aes           = ""
    ais           = ""
    aps           = ""
    lobby_backend = ""
  }
}

variable "cpu" {
  description = "CPU units for ECS tasks (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory in MB for ECS tasks"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 3
}

variable "health_check_path" {
  description = "Health check path for ALB target groups"
  type = object({
    server        = string
    lobby         = string
    afs           = string
    ahsat         = string
    aes           = string
    ais           = string
    aps           = string
    lobby_backend = string
  })
  default = {
    server        = "/health"
    lobby         = "/"
    afs           = "/ping"
    ahsat         = "/ping"
    aes           = "/health"
    ais           = "/health"
    aps           = "/v0/aps/ping"
    lobby_backend = "/health"
  }
}

variable "database_password" {
  description = "Password for RDS database connection"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "nakama_port" {
  description = "Port for server service (Nakama)"
  type        = number
  default     = 7350
}

variable "lobby_port" {
  description = "Port for lobby service"
  type        = number
  default     = 3000
}

variable "afs_port" {
  description = "Port for AFS service"
  type        = number
  default     = 9933
}

variable "ahsat_port" {
  description = "Port for AHSAT service"
  type        = number
  default     = 6969
}

variable "aes_port" {
  description = "Port for AES email service"
  type        = number
  default     = 1988
}

variable "ais_port" {
  description = "Port for AIS AI image service"
  type        = number
  default     = 5050
}

variable "aps_port" {
  description = "Port for APS image service"
  type        = number
  default     = 4444
}

variable "lobby_backend_port" {
  description = "Port for Lobby Backend service"
  type        = number
  default     = 3001
}

# ======================================================================
# SCHEDULER VARIABLES
# ======================================================================

variable "enable_scheduler" {
  description = "Enable automated environment shutdown/startup scheduler"
  type        = bool
  default     = false
}

variable "scheduler_enabled" {
  description = "Enable/disable scheduler EventBridge rules (allows temporary pause without destroying resources)"
  type        = bool
  default     = true
}

variable "scheduler_shutdown_cron" {
  description = "Cron expression for shutdown schedule (UTC timezone)"
  type        = string
  default     = "cron(0 23 ? * MON-FRI *)" # 20h BRT / 8 PM (23h UTC) Mon-Fri
}

variable "scheduler_startup_cron" {
  description = "Cron expression for startup schedule (UTC timezone)"
  type        = string
  default     = "cron(0 9 ? * MON-FRI *)" # 6h BRT / 6 AM (9h UTC) Mon-Fri
}

variable "scheduler_notification_email" {
  description = "Email address for scheduler notifications (leave empty to skip email subscription)"
  type        = string
  default     = ""
  sensitive   = true
}