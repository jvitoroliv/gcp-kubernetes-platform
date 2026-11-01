# -----------------------------------------------------------------------------
# WORKLOADS STACK
# This stack sets up supporting infrastructure for workloads:
# - Artifact Registry for container images
# - Secret Manager secrets
# - GitHub Actions OIDC authentication
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "workloads"
    managed_by  = "terraform"
  }, var.labels)

  # Naming convention
  name_prefix = "gameplatform-${var.environment}"
}

# -----------------------------------------------------------------------------
# ARTIFACT REGISTRY REPOSITORIES
# -----------------------------------------------------------------------------

module "artifact_registries" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/artifact-registry-repository"

  for_each = var.artifact_registries

  repository_id = "${local.name_prefix}-${each.key}"
  project       = var.project_id
  location      = var.region
  description   = each.value.description
  format        = each.value.format

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# SECRET MANAGER SECRETS
# Pre-created secrets for applications
# -----------------------------------------------------------------------------

module "secrets" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret"

  for_each = var.secrets

  secret_id          = "${local.name_prefix}-${each.key}"
  project            = var.project_id
  replication_policy = each.value.replication == "automatic" ? "auto" : "user_managed"
  rotation           = each.value.rotation

  labels = merge(local.common_labels, each.value.labels)
}

# Secret IAM bindings
resource "google_secret_manager_secret_iam_binding" "bindings" {
  for_each = var.secret_iam_bindings

  project   = var.project_id
  secret_id = each.value.secret_id
  role      = each.value.role
  members   = each.value.members

  depends_on = [module.secrets]
}

# -----------------------------------------------------------------------------
# GITHUB ACTIONS OIDC WORKLOAD IDENTITY
# Allows GitHub Actions to authenticate to GCP without service account keys
# -----------------------------------------------------------------------------

# Workload Identity Pool for GitHub
resource "google_iam_workload_identity_pool" "github" {
  count = var.enable_github_oidc ? 1 : 0

  project                   = var.project_id
  workload_identity_pool_id = "${local.name_prefix}-github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions"
}

# Workload Identity Pool Provider for GitHub OIDC
resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.enable_github_oidc ? 1 : 0

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC Provider"
  description                        = "OIDC provider for GitHub Actions"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = "assertion.repository_owner == '${var.github_org}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  depends_on = [google_iam_workload_identity_pool.github]
}

# Service account for GitHub Actions
module "github_actions_service_account" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-service-account"
  count  = var.enable_github_oidc ? 1 : 0

  account_id   = "${local.name_prefix}-github-actions"
  display_name = "GitHub Actions Service Account"
  description  = "Service account for GitHub Actions CI/CD"
  project      = var.project_id
}

# Grant roles to GitHub Actions service account
module "github_actions_sa_roles" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-project-iam-member"

  for_each = var.enable_github_oidc ? toset(var.github_oidc_service_account_roles) : []

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${module.github_actions_service_account[0].email}"

  depends_on = [module.github_actions_service_account]
}

# Allow GitHub Actions to impersonate the service account
resource "google_service_account_iam_member" "github_workload_identity" {
  for_each = var.enable_github_oidc ? toset(var.github_oidc_repos) : []

  service_account_id = module.github_actions_service_account[0].id
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[0].name}/attribute.repository/${var.github_org}/${each.value}"

  depends_on = [
    google_iam_workload_identity_pool.github,
    module.github_actions_service_account
  ]
}

# -----------------------------------------------------------------------------
# EXTERNAL SECRETS OPERATOR (ESO) SERVICE ACCOUNTS
# Allows ESO to read secrets from GCP Secret Manager
# One service account per cluster that needs ESO
# -----------------------------------------------------------------------------

# ESO Service Account for Workloads Cluster
module "eso_workloads_service_account" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-service-account"
  count  = var.enable_external_secrets ? 1 : 0

  account_id   = "${local.name_prefix}-eso-workloads"
  display_name = "External Secrets Operator - Workloads"
  description  = "Service account for ESO in workloads cluster to access Secret Manager"
  project      = var.project_id
}

# ESO Service Account for Runners Cluster
module "eso_runners_service_account" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-service-account"
  count  = var.enable_external_secrets ? 1 : 0

  account_id   = "${local.name_prefix}-eso-runners"
  display_name = "External Secrets Operator - Runners"
  description  = "Service account for ESO in runners cluster to access Secret Manager"
  project      = var.project_id
}

# Grant Secret Manager accessor role to ESO service accounts
resource "google_project_iam_member" "eso_workloads_secret_accessor" {
  count   = var.enable_external_secrets ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${module.eso_workloads_service_account[0].email}"
}

resource "google_project_iam_member" "eso_runners_secret_accessor" {
  count   = var.enable_external_secrets ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${module.eso_runners_service_account[0].email}"
}

# Workload Identity binding for ESO in Workloads Cluster
resource "google_service_account_iam_member" "eso_workloads_workload_identity" {
  count              = var.enable_external_secrets ? 1 : 0
  service_account_id = module.eso_workloads_service_account[0].id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]"
}

# Workload Identity binding for ESO in Runners Cluster
resource "google_service_account_iam_member" "eso_runners_workload_identity" {
  count              = var.enable_external_secrets ? 1 : 0
  service_account_id = module.eso_runners_service_account[0].id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]"
}

# -----------------------------------------------------------------------------
# CERT-MANAGER SERVICE ACCOUNT FOR DNS-01 CHALLENGE
# Allows cert-manager to create DNS records for Let's Encrypt validation
# -----------------------------------------------------------------------------

# Cert-Manager Service Account
module "cert_manager_service_account" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-service-account"
  count  = try(var.cert_manager_service_account.enabled, false) ? 1 : 0

  account_id   = var.cert_manager_service_account.name
  display_name = "Cert-Manager DNS-01"
  description  = "Service account for cert-manager to manage DNS records for Let's Encrypt"
  project      = var.project_id
}

# Grant DNS Admin role to cert-manager service account
resource "google_project_iam_member" "cert_manager_dns_admin" {
  count   = try(var.cert_manager_service_account.enabled, false) ? 1 : 0
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${module.cert_manager_service_account[0].email}"
}

# Workload Identity binding for cert-manager
resource "google_service_account_iam_member" "cert_manager_workload_identity" {
  count              = try(var.cert_manager_service_account.enabled, false) ? 1 : 0
  service_account_id = module.cert_manager_service_account[0].id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.cert_manager_service_account.namespace}/${var.cert_manager_service_account.k8s_service_account}]"
}

# -----------------------------------------------------------------------------
# MONITORING NOTIFICATION CHANNELS
# Using native resource since module doesn't exist
# -----------------------------------------------------------------------------

resource "google_monitoring_notification_channel" "channels" {
  for_each = var.enable_alerting ? var.notification_channels : {}

  project      = var.project_id
  display_name = each.value.display_name
  type         = each.value.type
  labels       = each.value.labels
}

# -----------------------------------------------------------------------------
# MONITORING ALERT POLICIES
# Using native resource since module doesn't exist
# -----------------------------------------------------------------------------

resource "google_monitoring_alert_policy" "policies" {
  for_each = var.enable_alerting ? var.alert_policies : {}

  project      = var.project_id
  display_name = each.value.display_name
  combiner     = each.value.combiner

  notification_channels = [
    for channel_key in each.value.notification_channels :
    google_monitoring_notification_channel.channels[channel_key].id
  ]

  dynamic "conditions" {
    for_each = each.value.conditions
    content {
      display_name = conditions.value.display_name

      dynamic "condition_threshold" {
        for_each = conditions.value.condition_threshold != null ? [conditions.value.condition_threshold] : []
        content {
          filter          = condition_threshold.value.filter
          duration        = condition_threshold.value.duration
          comparison      = condition_threshold.value.comparison
          threshold_value = condition_threshold.value.threshold_value

          dynamic "aggregations" {
            for_each = condition_threshold.value.aggregations != null ? condition_threshold.value.aggregations : []
            content {
              alignment_period   = aggregations.value.alignment_period
              per_series_aligner = aggregations.value.per_series_aligner
            }
          }
        }
      }
    }
  }

  depends_on = [google_monitoring_notification_channel.channels]
}

# -----------------------------------------------------------------------------
# GCS STORAGE BUCKETS
# For application file storage (AFS, AIS assets)
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "buckets" {
  for_each = var.storage_buckets

  name                        = each.key
  project                     = var.project_id
  location                    = coalesce(each.value.location, var.region)
  storage_class               = each.value.storage_class
  uniform_bucket_level_access = each.value.uniform_bucket_level_access
  public_access_prevention    = each.value.public_access_prevention

  versioning {
    enabled = each.value.versioning_enabled
  }

  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = lifecycle_rule.value.action.storage_class
      }
      condition {
        age                   = lifecycle_rule.value.condition.age
        created_before        = lifecycle_rule.value.condition.created_before
        num_newer_versions    = lifecycle_rule.value.condition.num_newer_versions
        with_state            = lifecycle_rule.value.condition.with_state
        matches_storage_class = lifecycle_rule.value.condition.matches_storage_class
      }
    }
  }

  labels = merge(local.common_labels, each.value.labels)
}

# Bucket IAM members
resource "google_storage_bucket_iam_member" "bucket_iam" {
  for_each = { for pair in flatten([
    for bucket_key, bucket_value in var.storage_buckets : [
      for iam in bucket_value.iam_members : {
        key    = "${bucket_key}-${iam.role}-${iam.member}"
        bucket = bucket_key
        role   = iam.role
        member = iam.member
      }
    ]
  ]) : pair.key => pair }

  bucket = google_storage_bucket.buckets[each.value.bucket].name
  role   = each.value.role
  member = each.value.member

  depends_on = [google_storage_bucket.buckets]
}

# -----------------------------------------------------------------------------
# HMAC KEYS FOR GCS S3-COMPATIBLE API
# Used by AFS and AIS for S3-compatible access to GCS
# -----------------------------------------------------------------------------

resource "google_storage_hmac_key" "keys" {
  for_each = var.hmac_keys

  project               = var.project_id
  service_account_email = each.value.service_account_email
}

# Store HMAC access key in Secret Manager
resource "google_secret_manager_secret_version" "hmac_access_keys" {
  for_each = var.hmac_keys

  secret      = "${local.name_prefix}-${each.value.secret_access_key_id}"
  secret_data = google_storage_hmac_key.keys[each.key].access_id

  depends_on = [module.secrets, google_storage_hmac_key.keys]
}

# Store HMAC secret key in Secret Manager
resource "google_secret_manager_secret_version" "hmac_secret_keys" {
  for_each = var.hmac_keys

  secret      = "${local.name_prefix}-${each.value.secret_secret_key_id}"
  secret_data = google_storage_hmac_key.keys[each.key].secret

  depends_on = [module.secrets, google_storage_hmac_key.keys]
}
