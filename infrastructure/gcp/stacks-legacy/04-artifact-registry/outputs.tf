output "repository_name" {
  description = "Name of the Artifact Registry repository"
  value       = module.repository.name
}

output "repository_id" {
  description = "ID of the Artifact Registry repository"
  value       = module.repository.id
}

output "repository_url" {
  description = "URL for Docker images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
}
