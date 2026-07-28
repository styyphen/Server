locals {
  environment = "aws"
  services = {
    object_storage = "s3"
    queue          = "sqs"
    database       = "dynamodb"
  }
}

output "environment" {
  value = local.environment
}

output "services" {
  value = local.services
}
