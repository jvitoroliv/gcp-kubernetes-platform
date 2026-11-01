# -----------------------------------------------------------------------------
# DNS RECORDS OUTPUTS
# -----------------------------------------------------------------------------

output "a_records" {
  description = "List of A records created"
  value = concat(
    [
      {
        name = google_dns_record_set.root_a.name
        type = google_dns_record_set.root_a.type
        ip   = var.alb_ip_address
      },
      {
        name = google_dns_record_set.wildcard_a.name
        type = google_dns_record_set.wildcard_a.type
        ip   = var.alb_ip_address
      },
      {
        name = google_dns_record_set.lobby_a.name
        type = google_dns_record_set.lobby_a.type
        ip   = var.alb_ip_address
      },
      {
        name = google_dns_record_set.app_a.name
        type = google_dns_record_set.app_a.type
        ip   = var.alb_ip_address
      }
    ],
    [for subdomain in var.service_subdomains : {
      name = google_dns_record_set.services_a[subdomain].name
      type = google_dns_record_set.services_a[subdomain].type
      ip   = var.alb_ip_address
    }]
  )
}

output "mx_records" {
  description = "List of MX records created"
  value = [
    {
      name    = google_dns_record_set.root_mx.name
      type    = google_dns_record_set.root_mx.type
      rrdatas = google_dns_record_set.root_mx.rrdatas
    }
  ]
}

output "txt_records" {
  description = "List of TXT records created"
  value = [
    {
      name    = google_dns_record_set.root_spf.name
      type    = google_dns_record_set.root_spf.type
      rrdatas = google_dns_record_set.root_spf.rrdatas
    },
    {
      name    = google_dns_record_set.dmarc.name
      type    = google_dns_record_set.dmarc.type
      rrdatas = google_dns_record_set.dmarc.rrdatas
    },
    {
      name    = google_dns_record_set.google_dkim.name
      type    = google_dns_record_set.google_dkim.type
      rrdatas = google_dns_record_set.google_dkim.rrdatas
    },
    {
      name    = google_dns_record_set.webflow_verification.name
      type    = google_dns_record_set.webflow_verification.type
      rrdatas = google_dns_record_set.webflow_verification.rrdatas
    }
  ]
}

output "cname_records" {
  description = "List of CNAME records created"
  value = [
    {
      name    = google_dns_record_set.ses_dkim_1.name
      type    = google_dns_record_set.ses_dkim_1.type
      rrdatas = google_dns_record_set.ses_dkim_1.rrdatas
    },
    {
      name    = google_dns_record_set.ses_dkim_2.name
      type    = google_dns_record_set.ses_dkim_2.type
      rrdatas = google_dns_record_set.ses_dkim_2.rrdatas
    },
    {
      name    = google_dns_record_set.ses_dkim_3.name
      type    = google_dns_record_set.ses_dkim_3.type
      rrdatas = google_dns_record_set.ses_dkim_3.rrdatas
    },
    {
      name    = google_dns_record_set.hubspot_dkim_1.name
      type    = google_dns_record_set.hubspot_dkim_1.type
      rrdatas = google_dns_record_set.hubspot_dkim_1.rrdatas
    },
    {
      name    = google_dns_record_set.hubspot_dkim_2.name
      type    = google_dns_record_set.hubspot_dkim_2.type
      rrdatas = google_dns_record_set.hubspot_dkim_2.rrdatas
    },
    {
      name    = google_dns_record_set.earn.name
      type    = google_dns_record_set.earn.type
      rrdatas = google_dns_record_set.earn.rrdatas
    },
    {
      name    = google_dns_record_set.hackathon.name
      type    = google_dns_record_set.hackathon.type
      rrdatas = google_dns_record_set.hackathon.rrdatas
    },
    {
      name    = google_dns_record_set.lifeforms.name
      type    = google_dns_record_set.lifeforms.type
      rrdatas = google_dns_record_set.lifeforms.rrdatas
    },
    {
      name    = google_dns_record_set.lightpaper.name
      type    = google_dns_record_set.lightpaper.type
      rrdatas = google_dns_record_set.lightpaper.rrdatas
    },
    {
      name    = google_dns_record_set.litepaper.name
      type    = google_dns_record_set.litepaper.type
      rrdatas = google_dns_record_set.litepaper.rrdatas
    },
    {
      name    = google_dns_record_set.protocol.name
      type    = google_dns_record_set.protocol.type
      rrdatas = google_dns_record_set.protocol.rrdatas
    },
    {
      name    = google_dns_record_set.www.name
      type    = google_dns_record_set.www.type
      rrdatas = google_dns_record_set.www.rrdatas
    }
  ]
}

output "total_records_created" {
  description = "Total number of DNS records created"
  value       = 4 + length(var.service_subdomains) + 1 + 4 + 12
}
