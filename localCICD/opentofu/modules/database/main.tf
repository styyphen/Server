locals {
  database_name = lower(replace(var.name, "_", "-"))
}
