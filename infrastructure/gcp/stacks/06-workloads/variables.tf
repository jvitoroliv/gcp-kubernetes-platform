# -----------------------------------------------------------------------------
# REQUIRED VARIABLES
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stg, prd, nonprod)"
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prd", "nonprod"], var.environment)
    error_message = "Environment must be one of: dev, stg, prd"
  }
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "southamerica-east1"
}

# -----------------------------------------------------------------------------
# ARTIFACT REGISTRY CONFIGURATION
# -----------------------------------------------------------------------------

variable "artifact_registries" {
  description = "Map of Artifact Registry repositories to create"
  type = map(object({
    description            = optional(string, "")
    format                 = optional(string, "DOCKER")
    mode                   = optional(string, "STANDARD_REPOSITORY")
    cleanup_policy_dry_run = optional(bool, false)
    cleanup_policies = optional(list(object({
      id     = string
      action = string
      condition = optional(object({
        tag_state             = optional(string)
        tag_prefixes          = optional(list(string))
        older_than            = optional(string)
        newer_than            = optional(string)
        package_name_prefixes = optional(list(string))
        version_name_prefixes = optional(list(string))
      }))
      most_recent_versions = optional(object({
        keep_count            = optional(number)
        package_name_prefixes = optional(list(string))
      }))
    })), [])
  }))
  default = {
    gameplatform = {
      description = "GamePlatform container images"
      format      = "DOCKER"
      cleanup_policies = [
        {
          id     = "delete-untagged"
          action = "DELETE"
          condition = {
            tag_state  = "UNTAGGED"
            older_than = "604800s" # 7 days
          }
        },
        {
          id     = "keep-recent"
          action = "KEEP"
          most_recent_versions = {
            keep_count = 10
          }
        }
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# SECRET MANAGER CONFIGURATION
# -----------------------------------------------------------------------------

variable "secrets" {
  description = "Map of secrets to create in Secret Manager"
  type = map(object({
    description  = optional(string, "")
    replication  = optional(string, "automatic")
    regions      = optional(list(string), [])
    rotation     = optional(object({
      rotation_period    = string
      next_rotation_time = optional(string)
    }))
    version_aliases = optional(map(string), {})
    labels          = optional(map(string), {})
  }))
  default = {}
}

variable "secret_iam_bindings" {
  description = "IAM bindings for secrets"
  type = map(object({
    secret_id = string
    role      = string
    members   = list(string)
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# EXTERNAL SECRETS OPERATOR CONFIGURATION
# -----------------------------------------------------------------------------

variable "enable_external_secrets" {
  description = "Enable External Secrets Operator service accounts"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# GITHUB ACTIONS OIDC CONFIGURATION
# -----------------------------------------------------------------------------

variable "enable_github_oidc" {
  description = "Enable GitHub Actions OIDC authentication"
  type        = bool
  default     = true
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "example-gamedev-org"
}

variable "github_oidc_repos" {
  description = "GitHub repositories allowed to authenticate via OIDC"
  type        = list(string)
  default     = []
}

variable "github_oidc_service_account_roles" {
  description = "Roles to grant to the GitHub Actions service account"
  type        = list(string)
  default = [
    "roles/artifactregistry.writer",
    "roles/container.developer",
    "roles/storage.admin",
  ]
}

# -----------------------------------------------------------------------------
# CERT-MANAGER CONFIGURATION
# -----------------------------------------------------------------------------

variable "cert_manager_service_account" {
  description = "Cert-Manager service account configuration for DNS-01 challenge"
  type = object({
    enabled            = bool
    name               = string
    namespace          = string
    k8s_service_account = string
  })
  default = {
    enabled            = false
    name               = ""
    namespace          = "cert-manager"
    k8s_service_account = "cert-manager"
  }
}

# -----------------------------------------------------------------------------
# MONITORING CONFIGURATION
# -----------------------------------------------------------------------------

variable "enable_alerting" {
  description = "Enable monitoring alert policies"
  type        = bool
  default     = false
}

variable "notification_channels" {
  description = "Map of notification channels to create"
  type = map(object({
    type         = string
    display_name = string
    labels       = map(string)
  }))
  default = {}
}

variable "alert_policies" {
  description = "Map of alert policies to create"
  type = map(object({
    display_name          = string
    combiner              = optional(string, "OR")
    notification_channels = optional(list(string), [])
    conditions = list(object({
      display_name = string
      condition_threshold = object({
        filter          = string
        duration        = string
        comparison      = string
        threshold_value = number
        aggregations = optional(list(object({
          alignment_period   = string
          per_series_aligner = string
        })), [])
      })
    }))
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# GCS BUCKET CONFIGURATION
# -----------------------------------------------------------------------------

variable "storage_buckets" {
  description = "Map of GCS storage buckets to create"
  type = map(object({
    location                    = optional(string)
    storage_class               = optional(string, "STANDARD")
    uniform_bucket_level_access = optional(bool, true)
    public_access_prevention    = optional(string, "enforced")
    versioning_enabled          = optional(bool, false)
    labels                      = optional(map(string), {})
    lifecycle_rules = optional(list(object({
      action = object({
        type          = string
        storage_class = optional(string)
      })
      condition = object({
        age                   = optional(number)
        created_before        = optional(string)
        num_newer_versions    = optional(number)
        with_state            = optional(string)
        matches_storage_class = optional(list(string))
      })
    })), [])
    iam_members = optional(list(object({
      role   = string
      member = string
    })), [])
  }))
  default = {}
}

variable "hmac_keys" {
  description = "Map of HMAC keys to create for GCS S3-compatible API access"
  type = map(object({
    service_account_email = string
    secret_access_key_id  = string
    secret_secret_key_id  = string
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# LABELS
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
