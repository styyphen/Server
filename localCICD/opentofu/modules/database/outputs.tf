output "name" {
  description = "Database name."
  value       = local.database_name
}

output "engine" {
  description = "Database engine label."
  value       = var.engine
}
