output "dns_zone_names" {
  description = "Map of DNS zone names"
  value       = { for k, v in module.dns_zones : k => v.name }
}

output "dns_zone_name_servers" {
  description = "Map of DNS zone name servers"
  value       = { for k, v in module.dns_zones : k => v.name_servers }
}

output "dns_record_names" {
  description = "Map of DNS record names"
  value       = { for k, v in module.dns_records : k => v.name }
}
