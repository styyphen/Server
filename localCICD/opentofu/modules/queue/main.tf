locals {
  queue_name      = lower(replace(var.name, "_", "-"))
  deadletter_name = "${local.queue_name}-deadletters"
}
