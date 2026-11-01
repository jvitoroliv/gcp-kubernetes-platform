output "instance_name" {
  description = "Name of the compute instance"
  value       = module.instance.name
}

output "instance_id" {
  description = "ID of the compute instance"
  value       = module.instance.id
}

output "instance_self_link" {
  description = "Self link of the compute instance"
  value       = module.instance.self_link
}

output "instance_internal_ip" {
  description = "Internal IP of the instance"
  value       = module.instance.internal_ip
}

output "instance_external_ip" {
  description = "External IP of the instance"
  value       = var.assign_public_ip ? google_compute_address.static_ip[0].address : null
}

output "instance_zone" {
  description = "Zone of the instance"
  value       = module.instance.zone
}
