variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (legacy)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "enable_apis" {
  description = "List of GCP APIs to enable"
  type        = list(string)
  default     = []
}

variable "service_accounts" {
  description = "Map of service accounts to create"
  type = map(object({
    display_name = string
    description  = optional(string)
    roles        = list(string)
  }))
  default = {}
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# GITHUB ACTIONS OIDC
# -----------------------------------------------------------------------------

variable "enable_github_oidc" {
  description = "Enable GitHub Actions OIDC authentication"
  type        = bool
  default     = false
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "example-gamedev-org"
}

variable "github_oidc_repos" {
  description = "List of GitHub repos that can authenticate"
  type        = list(string)
  default     = []
}

variable "github_oidc_service_account_roles" {
  description = "IAM roles to grant to GitHub Actions service account"
  type        = list(string)
  default = [
    "roles/artifactregistry.admin",
    "roles/storage.admin",
    "roles/secretmanager.admin",
    "roles/iam.serviceAccountUser",
    "roles/run.admin",
    "roles/compute.admin",
    "roles/dns.admin",
    "roles/iam.securityAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/editor",
  ]
}
