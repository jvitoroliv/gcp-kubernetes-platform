# -----------------------------------------------------------------------------
# COMPUTE STACK - LEGACY
# Creates GCE instance for Rogues game server
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "compute"
    managed_by  = "terraform"
  }, var.labels)
}

# -----------------------------------------------------------------------------
# STATIC EXTERNAL IP (optional)
# -----------------------------------------------------------------------------

resource "google_compute_address" "static_ip" {
  count = var.assign_public_ip ? 1 : 0

  name         = "${var.instance_name}-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

# -----------------------------------------------------------------------------
# COMPUTE INSTANCE
# -----------------------------------------------------------------------------

module "instance" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/compute-instance"

  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  project      = var.project_id

  boot_disk = var.boot_disk

  network    = var.network
  subnetwork = var.subnetwork

  assign_public_ip = var.assign_public_ip
  static_ip        = var.assign_public_ip ? google_compute_address.static_ip[0].address : null

  tags = var.tags

  service_account = var.service_account

  startup_script = var.startup_script

  labels = local.common_labels
}
