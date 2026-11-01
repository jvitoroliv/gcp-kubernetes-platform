# -----------------------------------------------------------------------------
# FOUNDATION STACK - LEGACY
# This stack sets up the foundation for Rogues migration:
# - Enables required GCP APIs
# - Creates IAM service accounts
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "foundation"
    managed_by  = "terraform"
  }, var.labels)

  # Shorter prefix for legacy to stay within 30 char SA limit
  name_prefix = "leg"
}

# -----------------------------------------------------------------------------
# ENABLE GCP APIs
# -----------------------------------------------------------------------------

resource "google_project_service" "apis" {
  for_each = toset(var.enable_apis)

  project = var.project_id
  service = each.value

  disable_on_destroy         = false
  disable_dependent_services = false
}

# -----------------------------------------------------------------------------
# SERVICE ACCOUNTS
# -----------------------------------------------------------------------------

module "service_accounts" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-service-account"
  for_each = var.service_accounts

  account_id   = "${local.name_prefix}-${each.key}"
  display_name = each.value.display_name
  description  = each.value.description
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

# Service Account IAM Roles
module "service_account_roles" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-project-iam-member"
  for_each = { for pair in flatten([
    for sa_key, sa_value in var.service_accounts : [
      for role in sa_value.roles : {
        key    = "${sa_key}-${replace(role, "/", "-")}"
        sa_key = sa_key
        role   = role
      }
    ]
  ]) : pair.key => pair }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${module.service_accounts[each.value.sa_key].email}"

  depends_on = [module.service_accounts]
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
  display_name              = "GitHub Actions Pool (Legacy)"
  description               = "Workload Identity Pool for GitHub Actions - Legacy Environment"

  depends_on = [google_project_service.apis]
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
  display_name = "GitHub Actions Service Account (Legacy)"
  description  = "Service account for GitHub Actions CI/CD - Legacy Environment"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

# Grant roles to GitHub Actions service account
module "github_actions_sa_roles" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-project-iam-member"

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
