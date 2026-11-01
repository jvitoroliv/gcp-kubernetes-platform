variable "region" {
  description = "AWS region for Metabase resources"
  type        = string
  default     = "sa-east-1"
}

variable "environment" {
  description = "Environment name (live)"
  type        = string
  default     = "live"
}

variable "domain_name" {
  description = "Base domain for production environments"
  type        = string
  default     = "gameplatform.example.com"
}

variable "ami_id" {
  description = "AMI ID for Metabase instances"
  type        = string
  default     = "ami-029ffa56aa94a3c9f"
}

variable "instance_type" {
  description = "EC2 instance type for Metabase"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "SSH key pair name for EC2 instances"
  type        = string
  default     = "golden-gate-live"
}

variable "min_size" {
  description = "Minimum number of instances in Auto Scaling Group"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in Auto Scaling Group"
  type        = number
  default     = 1
}

variable "desired_capacity" {
  description = "Desired number of instances in Auto Scaling Group"
  type        = number
  default     = 1
}

variable "metabase_port" {
  description = "Port for Metabase application"
  type        = number
  default     = 3000
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 30
}

variable "database_endpoint" {
  description = "Database endpoint for Metabase to connect to"
  type        = string
  default     = ""
}

variable "database_name" {
  description = "Database name for Metabase"
  type        = string
  default     = "metabase"
}

variable "database_username" {
  description = "Database username for Metabase"
  type        = string
  default     = "metabase"
}

variable "database_password" {
  description = "Database password for Metabase"
  type        = string
  sensitive   = true
}

variable "listener_rule_priority" {
  description = "Priority for ALB listener rule"
  type        = number
  default     = 200
}

variable "log_retention_days" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 30
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}