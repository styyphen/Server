locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

module "artifacts" {
  source        = "../../modules/object-storage"
  name          = "${local.name_prefix}-artifacts"
  provider_name = "localstack"
}

module "uploads" {
  source        = "../../modules/object-storage"
  name          = "${local.name_prefix}-uploads"
  provider_name = "fake-gcs-server"
}

module "events" {
  source             = "../../modules/queue"
  name               = "${local.name_prefix}-events"
  deadletter_enabled = true
}

module "state" {
  source = "../../modules/database"
  name   = "${local.name_prefix}-state"
  engine = "dynamodb-local"
}
