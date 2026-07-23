locals {
  normalized_name = lower(replace(var.name, "_", "-"))
}
