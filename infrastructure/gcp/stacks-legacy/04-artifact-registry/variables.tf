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

variable "repository_id" {
  description = "ID of the Artifact Registry repository"
  type        = string
}

variable "description" {
  description = "Description of the repository"
  type        = string
  default     = ""
}

variable "format" {
  description = "Format of the repository (DOCKER, NPM, etc)"
  type        = string
  default     = "DOCKER"
}

variable "repository_iam_members" {
  description = "List of IAM members for the repository"
  type = list(object({
    role   = string
    member = string
  }))
  default = []
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
