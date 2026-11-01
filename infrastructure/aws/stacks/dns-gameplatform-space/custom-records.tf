# # Custom Route53 Records for gameplatform.example.com
# # Allows flexible management of DNS records with various configurations

# locals {
#   # DNS Records migrated from Namecheap to Route53
#   custom_records = {
#     # ========================================
#     # CNAME Records
#     # ========================================
#     "eam" = {
#       name    = "eam"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["snag-web.onrender.com"]
#     }

#     "hs1-domainkey" = {
#       name    = "hs1-44821273._domainkey"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["gameplatform-dns.hs09a.dkim.hubspotemail.net"]
#     }

#     "hs2-domainkey" = {
#       name    = "hs2-44821273._domainkey"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["gameplatform-dns.hs09b.dkim.hubspotemail.net"]
#     }

#     "lifeforms-webflow" = {
#       name    = "lifeforms"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["proxy-ssl.webflow.com"]
#     }

#     "lightpaper" = {
#       name    = "lightpaper"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["dc4e227521-hosting.gitbook.io"]
#     }

#     "litepaper" = {
#       name    = "litepaper"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["proxy-ssl.webflow.com"]
#     }

#     "ses-dkim-1" = {
#       name    = "m2svhij7upvnewu7rldodbcc55sxaln._domainkey"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["m2svhij7upvnewu7rldodbcc55sxaln.dkim.amazonses.com"]
#     }

#     "protocol" = {
#       name    = "protocol"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["cdn.webflow.com"]
#     }

#     "rewards" = {
#       name    = "rewards"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["snag-web.onrender.com"]
#     }

#     "www" = {
#       name    = "www"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["proxy-ssl.webflow.com"]
#     }

#     "wou-ssl-validation" = {
#       name    = "_36cba460089b57e60a8461Bb32b45836a.wou"
#       type    = "CNAME"
#       ttl     = 60
#       records = ["721F497246C8AB8C6171E393407C35FA.979B68731AC70B6EEA1B56A1B63445AB.e255126ec27ae51.comodoca.com"]
#     }

#     "ses-dkim-2" = {
#       name    = "4ujjngnw56rvhfxk2vzrf2zoswyivubuj._domainkey"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["4ujjngnw56rvhfxk2vzrf2zoswyivubuj.dkim.amazonses.com"]
#     }

#     "ses-dkim-3" = {
#       name    = "clh5vwtaepjmyzryyu67tsibtvs5hvgc._domainkey"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["clh5vwtaepjmyzryyu67tsibtvs5hvgc.dkim.amazonses.com"]
#     }

#     "ses-dkim-3-a" = {
#       name    = "clh5vwtaepjmyzryyu67tsibtvs5hvgc._domainkey.a"
#       type    = "CNAME"
#       ttl     = 300
#       records = ["clh5vwtaepjmyzryyu67tsibtvs5hvgc.dkim.amazonses.com"]
#     }

#     # ========================================
#     # TXT Records
#     # ========================================
#     "google-verification-1" = {
#       name    = ""
#       type    = "TXT"
#       ttl     = 300
#       records = ["google-site-verification=-uA0OQsP4Rv4BsbkWOcDc0r57AM7-7_DB689IVNdTcAs"]
#     }

#     "spf-record" = {
#       name    = ""
#       type    = "TXT"
#       ttl     = 60
#       records = ["v=spf1 include:_spf.google.com include:44821273.spf06.hubspotemail.net ~all"]
#     }

#     "google-verification-2" = {
#       name    = ""
#       type    = "TXT"
#       ttl     = 300
#       records = ["google-site-verification=6nt0beVec6HtDTlcB2Ym5d3DxcICc6exAL1aRHkuWBjw"]
#     }

#     "dmarc" = {
#       name    = "_dmarc"
#       type    = "TXT"
#       ttl     = 300
#       records = ["v=DMARC1; p=none; rua=mailto:devops-lead@example-gamedev.com;"]
#     }

#     "webflow-verification" = {
#       name    = "_webflow"
#       type    = "TXT"
#       ttl     = 300
#       records = ["one-time-verification=a47805d5-7a80-4d4c-a860-8bcd8550ae97"]
#     }

#     "webflow-lifeforms-verification" = {
#       name    = "_webflow.lifeforms"
#       type    = "TXT"
#       ttl     = 300
#       records = ["one-time-verification=6eb4e9d2-15e5-474d-bd7b-6952296c3e44"]
#     }

#     "webflow-protocol-verification" = {
#       name    = "_webflow.protocol"
#       type    = "TXT"
#       ttl     = 300
#       records = ["one-time-verification=21ec84d6-837e-4fdc-9081-5c6d224f26e8"]
#     }

#     "google-dkim" = {
#       name    = "google._domainkey"
#       type    = "TXT"
#       ttl     = 300
#       records = ["v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxvHtDSPPCc1O9q68dIFuxS6ltY8qtNHLGPwPiT1ghr4VyybGcsczoyNtXRU"]
#     }

#     # ========================================
#     # A Records
#     # ========================================
#     # NOTE: Apex domain (gameplatform.example.com) is managed by ALB alias in main.tf
#     # Webflow apex records commented out to avoid conflict
#     # "apex-webflow-1" = {
#     #   name    = ""
#     #   type    = "A"
#     #   ttl     = 300
#     #   records = ["75.2.70.75"]
#     # }

#     # "apex-webflow-2" = {
#     #   name    = ""
#     #   type    = "A"
#     #   ttl     = 300
#     #   records = ["198.202.211.1"]
#     # }

#     "jobs" = {
#       name    = "jobs"
#       type    = "A"
#       ttl     = 300
#       records = ["54.194.41.141"]
#     }

#     "learnmore" = {
#       name    = "learnmore"
#       type    = "A"
#       ttl     = 300
#       records = ["54.194.41.141"]
#     }

#     "policy" = {
#       name    = "policy"
#       type    = "A"
#       ttl     = 300
#       records = ["54.194.41.141"]
#     }

#     "sutras" = {
#       name    = "sutras"
#       type    = "A"
#       ttl     = 300
#       records = ["54.194.41.141"]
#     }

#     "ucberkley" = {
#       name    = "ucberkley"
#       type    = "A"
#       ttl     = 300
#       records = ["54.194.41.141"]
#     }

#     "wou" = {
#       name    = "wou"
#       type    = "A"
#       ttl     = 300
#       records = ["35.176.148.118"]
#     }
#   }
# }

# # Create Route53 records based on the configuration
# resource "aws_route53_record" "custom" {
#   for_each = local.custom_records

#   zone_id = local.hosted_zone_id
#   name    = each.value.name != "" ? "${each.value.name}.${var.domain_name}" : var.domain_name
#   type    = each.value.type

#   # Simple records (A, AAAA, CNAME, MX, TXT, etc.)
#   ttl     = try(each.value.ttl, null)
#   records = try(each.value.records, null)

#   # Alias records (for ALB, CloudFront, S3, etc.)
#   dynamic "alias" {
#     for_each = try(each.value.alias, null) != null ? [each.value.alias] : []
#     content {
#       name                   = alias.value.name
#       zone_id                = alias.value.zone_id
#       evaluate_target_health = try(alias.value.evaluate_target_health, false)
#     }
#   }

#   # Routing policies
#   set_identifier = try(each.value.set_identifier, null)

#   # Weighted routing
#   dynamic "weighted_routing_policy" {
#     for_each = try(each.value.weighted_routing_policy, null) != null ? [each.value.weighted_routing_policy] : []
#     content {
#       weight = weighted_routing_policy.value.weight
#     }
#   }

#   # Latency routing
#   dynamic "latency_routing_policy" {
#     for_each = try(each.value.latency_routing_policy, null) != null ? [each.value.latency_routing_policy] : []
#     content {
#       region = latency_routing_policy.value.region
#     }
#   }

#   # Geolocation routing
#   dynamic "geolocation_routing_policy" {
#     for_each = try(each.value.geolocation_routing_policy, null) != null ? [each.value.geolocation_routing_policy] : []
#     content {
#       continent   = try(geolocation_routing_policy.value.continent, null)
#       country     = try(geolocation_routing_policy.value.country, null)
#       subdivision = try(geolocation_routing_policy.value.subdivision, null)
#     }
#   }

#   # Failover routing
#   dynamic "failover_routing_policy" {
#     for_each = try(each.value.failover_routing_policy, null) != null ? [each.value.failover_routing_policy] : []
#     content {
#       type = failover_routing_policy.value.type
#     }
#   }

#   # Multivalue answer routing
#   multivalue_answer_routing_policy = try(each.value.multivalue_answer_routing_policy, null)

#   # Health check for failover/multivalue
#   health_check_id = try(each.value.health_check_id, null)

#   # Prevent conflicts with existing wildcard/apex records from main.tf
#   lifecycle {
#     create_before_destroy = true
#   }
# }
