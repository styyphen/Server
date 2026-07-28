locals {
  environment = "azure"
  services = {
    object_storage = "blob-storage"
    queue          = "queue-storage"
    database       = "table-storage"
  }
}

output "environment" {
  value = local.environment
}

output "services" {
  value = local.services
}
