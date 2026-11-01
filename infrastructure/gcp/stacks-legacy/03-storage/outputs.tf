output "bucket_name" {
  description = "Name of the GCS bucket"
  value       = module.bucket.name
}

output "bucket_url" {
  description = "URL of the GCS bucket"
  value       = "gs://${module.bucket.name}"
}

output "bucket_self_link" {
  description = "Self link of the GCS bucket"
  value       = module.bucket.self_link
}
