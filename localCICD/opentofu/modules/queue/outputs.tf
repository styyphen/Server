output "name" {
  description = "Queue name."
  value       = local.queue_name
}

output "deadletter_name" {
  description = "Dead-letter queue name when enabled."
  value       = var.deadletter_enabled ? local.deadletter_name : null
}
