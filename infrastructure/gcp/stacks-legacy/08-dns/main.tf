# -----------------------------------------------------------------------------
# DNS STACK - LEGACY
# Creates Cloud DNS zones and records for Rogues
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "dns"
    managed_by  = "terraform"
  }, var.labels)
}

# -----------------------------------------------------------------------------
# DNS ZONES
# -----------------------------------------------------------------------------

module "dns_zones" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-dns-zone"
  for_each = var.dns_zones

  name        = each.key
  dns_name    = each.value.dns_name
  description = each.value.description
  project     = var.project_id
  visibility  = each.value.visibility

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# DNS RECORDS
# -----------------------------------------------------------------------------

module "dns_records" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-dns-record"
  for_each = var.dns_records

  name         = each.value.name
  type         = each.value.type
  ttl          = each.value.ttl
  managed_zone = module.dns_zones[each.value.zone].name
  project      = var.project_id
  rrdatas      = each.value.rrdatas

  depends_on = [module.dns_zones]
}
