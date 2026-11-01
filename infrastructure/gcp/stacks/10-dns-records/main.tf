# -----------------------------------------------------------------------------
# DNS RECORDS STACK
# This stack creates DNS records in Cloud DNS for the gameplatform.example.com domain
# Migrating from AWS Route53 hosted zone Z058983535M8LMA6QEXJ6
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "dns-records"
    managed_by  = "terraform"
  }, var.labels)
}

# -----------------------------------------------------------------------------
# A RECORDS - Services pointing to GCP Load Balancer
# These records point to the GCP ALB IP (198.51.100.10)
# -----------------------------------------------------------------------------

# Root domain
resource "google_dns_record_set" "root_a" {
  name         = "${var.dns_zone_dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = [var.alb_ip_address]
}

# Wildcard record (catches all subdomains not explicitly defined)
resource "google_dns_record_set" "wildcard_a" {
  name         = "*.${var.dns_zone_dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = [var.alb_ip_address]
}

# Application services
resource "google_dns_record_set" "services_a" {
  for_each = toset(var.service_subdomains)

  name         = "${each.value}.${var.dns_zone_dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = [var.alb_ip_address]
}

# Lobby subdomain
resource "google_dns_record_set" "lobby_a" {
  name         = "lobby.${var.dns_zone_dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = [var.alb_ip_address]
}

# App subdomain (same as lobby)
resource "google_dns_record_set" "app_a" {
  name         = "app.${var.dns_zone_dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = [var.alb_ip_address]
}

# -----------------------------------------------------------------------------
# MX RECORDS - Email
# -----------------------------------------------------------------------------

resource "google_dns_record_set" "root_mx" {
  name         = "${var.dns_zone_dns_name}"
  type         = "MX"
  ttl          = 60
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["1 smtp.google.com."]
}

# -----------------------------------------------------------------------------
# TXT RECORDS - SPF, DKIM, DMARC, Verification
# -----------------------------------------------------------------------------

# SPF record for root domain
resource "google_dns_record_set" "root_spf" {
  name         = "${var.dns_zone_dns_name}"
  type         = "TXT"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["\"v=spf1 include:_spf.google.com include:amazonses.com include:44821273.spf06.hubspotemail.net ~all\""]
}

# DMARC record
resource "google_dns_record_set" "dmarc" {
  name         = "_dmarc.${var.dns_zone_dns_name}"
  type         = "TXT"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["\"v=DMARC1; p=none;\""]
}

# Google DKIM record
resource "google_dns_record_set" "google_dkim" {
  name         = "google._domainkey.${var.dns_zone_dns_name}"
  type         = "TXT"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["\"v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDulRPgvHtl8jWJw4TwYfJMvuukKNTt1AVa7DU3v/DmT7tqeDYZU8sns3HzoM+L6vZJSTVBD451ZBDs0gCDKzZqzvDMrv4IKPrbSixC7LzcUMHnDrhT7f/7SemK59Tr3YA7GpZbuRiePwlIM5cPBl/B/aDEbt2itDdwLXA8lWEYeQIDAQAB\""]
}

# Webflow verification
resource "google_dns_record_set" "webflow_verification" {
  name         = "_webflow.${var.dns_zone_dns_name}"
  type         = "TXT"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["\"one-time-verification=3d1a9059-6f74-4d28-89f5-d9e53ac4d2db\""]
}

# -----------------------------------------------------------------------------
# CNAME RECORDS - DKIM and External Services
# -----------------------------------------------------------------------------

# Amazon SES DKIM records
resource "google_dns_record_set" "ses_dkim_1" {
  name         = "4ujjngnw56rvfxrk2vzvf2zoswywbbuj._domainkey.${var.dns_zone_dns_name}"
  type         = "CNAME"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["4ujjngnw56rvfxrk2vzvf2zoswywbbuj.dkim.amazonses.com."]
}

resource "google_dns_record_set" "ses_dkim_2" {
  name         = "ciiv5vwtaepjmyzrxyu67tslbxv5hvgc._domainkey.${var.dns_zone_dns_name}"
  type         = "CNAME"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["ciiv5vwtaepjmyzrxyu67tslbxv5hvgc.dkim.amazonses.com."]
}

resource "google_dns_record_set" "ses_dkim_3" {
  name         = "m2svhji7upvnewuv7ridodbce55sxaln._domainkey.${var.dns_zone_dns_name}"
  type         = "CNAME"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["m2svhji7upvnewuv7ridodbce55sxaln.dkim.amazonses.com."]
}

# HubSpot DKIM records
resource "google_dns_record_set" "hubspot_dkim_1" {
  name         = "hs1-44821273._domainkey.${var.dns_zone_dns_name}"
  type         = "CNAME"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["gameplatform-dns.hs09a.dkim.hubspotemail.net."]
}

resource "google_dns_record_set" "hubspot_dkim_2" {
  name         = "hs2-44821273._domainkey.${var.dns_zone_dns_name}"
  type         = "CNAME"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["gameplatform-dns.hs09b.dkim.hubspotemail.net."]
}

# External services CNAME records
resource "google_dns_record_set" "earn" {
  name         = "earn.${var.dns_zone_dns_name}"
  type         = "CNAME"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["snag-web.onrender.com."]
}

resource "google_dns_record_set" "hackathon" {
  name         = "hackathon.${var.dns_zone_dns_name}"
  type         = "CNAME"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["44821273.group23.sites.hubspot.net."]
}

resource "google_dns_record_set" "lifeforms" {
  name         = "lifeforms.${var.dns_zone_dns_name}"
  type         = "CNAME"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["proxy-ssl.webflow.com."]
}

resource "google_dns_record_set" "lightpaper" {
  name         = "lightpaper.${var.dns_zone_dns_name}"
  type         = "CNAME"
  ttl          = 60
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["dc4e227521-hosting.gitbook.io."]
}

resource "google_dns_record_set" "litepaper" {
  name         = "litepaper.${var.dns_zone_dns_name}"
  type         = "CNAME"
  ttl          = 60
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["proxy-ssl.webflow.com."]
}

resource "google_dns_record_set" "protocol" {
  name         = "protocol.${var.dns_zone_dns_name}"
  type         = "CNAME"
  ttl          = 300
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["cdn.webflow.com."]
}

resource "google_dns_record_set" "www" {
  name         = "www.${var.dns_zone_dns_name}"
  type         = "CNAME"
  ttl          = 60
  managed_zone = var.dns_zone_name
  project      = var.project_id
  rrdatas      = ["cdn.webflow.com."]
}
