locals {
  environment = "gcp"
  services = {
    object_storage = "cloud-storage"
    queue          = "pubsub"
    database       = "firestore"
  }
}

output "environment" {
  value = local.environment
}

output "services" {
  value = local.services
}
