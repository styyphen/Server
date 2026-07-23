output "name" {
  description = "Normalized storage name."
  value       = local.normalized_name
}

output "provider_name" {
  description = "Provider label."
  value       = var.provider_name
}
