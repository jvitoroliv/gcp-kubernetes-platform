# -----------------------------------------------------------------------------
# FOUNDATION STACK
# This stack sets up the foundation for GCP infrastructure:
# - Enables required GCP APIs
# - Creates IAM service accounts for GKE, Cloud SQL, and workloads
# - Sets up base IAM permissions
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "foundation"
    managed_by  = "terraform"
  }, var.labels)

  # Naming convention
  name_prefix = "gameplatform-${var.environment}"
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
# GKE NODE SERVICE ACCOUNT
# Service account used by GKE nodes for pulling images and logging
# -----------------------------------------------------------------------------

module "gke_node_service_account" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-service-account"
  count  = var.create_gke_service_account ? 1 : 0

  account_id   = "${local.name_prefix}-gke-nodes"
  display_name = "GKE Nodes Service Account"
  description  = "Service account for GKE node pools in ${var.environment} environment"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

# GKE Node Service Account IAM Roles
module "gke_node_sa_roles" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-project-iam-member"
  for_each = var.create_gke_service_account ? toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
    "roles/storage.objectViewer",
  ]) : []

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${module.gke_node_service_account[0].email}"

  depends_on = [module.gke_node_service_account]
}

# -----------------------------------------------------------------------------
# CLOUD SQL SERVICE ACCOUNT
# Service account for Cloud SQL admin operations
# -----------------------------------------------------------------------------

module "cloudsql_service_account" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-service-account"
  count  = var.create_cloudsql_service_account ? 1 : 0

  account_id   = "${local.name_prefix}-cloudsql"
  display_name = "Cloud SQL Service Account"
  description  = "Service account for Cloud SQL operations in ${var.environment} environment"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

# Cloud SQL Service Account IAM Roles
module "cloudsql_sa_roles" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-project-iam-member"
  for_each = var.create_cloudsql_service_account ? toset([
    "roles/cloudsql.admin",
    "roles/secretmanager.secretAccessor",
  ]) : []

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${module.cloudsql_service_account[0].email}"

  depends_on = [module.cloudsql_service_account]
}

# -----------------------------------------------------------------------------
# WORKLOAD IDENTITY SERVICE ACCOUNTS
# Service accounts for Kubernetes workloads using Workload Identity
# -----------------------------------------------------------------------------

module "workload_identity_service_accounts" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-service-account"
  for_each = var.create_workload_identity_service_accounts

  account_id   = "${local.name_prefix}-${each.key}"
  display_name = each.value.display_name
  description  = coalesce(each.value.description, "Workload Identity SA for ${each.key} in ${var.environment}")
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

# Workload Identity Service Account IAM Roles
module "workload_identity_sa_roles" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/iam-project-iam-member"
  for_each = { for pair in flatten([
    for sa_key, sa_value in var.create_workload_identity_service_accounts : [
      for role in sa_value.roles : {
        key    = "${sa_key}-${role}"
        sa_key = sa_key
        role   = role
      }
    ]
  ]) : pair.key => pair }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${module.workload_identity_service_accounts[each.value.sa_key].email}"

  depends_on = [module.workload_identity_service_accounts]
}

# Workload Identity Bindings
# Allows Kubernetes ServiceAccounts to impersonate GCP Service Accounts
resource "google_service_account_iam_member" "workload_identity_bindings" {
  for_each = { for sa_key, sa_value in var.create_workload_identity_service_accounts :
    sa_key => sa_value if sa_value.workload_identity_binding != null
  }

  service_account_id = module.workload_identity_service_accounts[each.key].id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.workload_identity_binding.namespace}/${each.value.workload_identity_binding.k8s_service_account}]"

  depends_on = [module.workload_identity_service_accounts]
}

# -----------------------------------------------------------------------------
# TERRAFORM STATE BUCKET (state bucket created manually for now)
# -----------------------------------------------------------------------------

# module "terraform_state_bucket" {
# source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-storage-bucket"
# source = "../../../gameplatform-terraform/modules/gcp/cloud-storage-bucket"
#
#   name          = "gameplatform-terraform-state"
#   location      = var.region
#   project       = var.project_id
#   storage_class = "STANDARD"
#
#   versioning = true
#
#   lifecycle_rules = [
#     {
#       action = {
#         type = "Delete"
#       }
#       condition = {
#         num_newer_versions = 5
#       }
#     }
#   ]
#
#   labels = local.common_labels
# }
