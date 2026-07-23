package opentofu.tags

deny[msg] {
  resource := input.resource_changes[_]
  resource.mode == "managed"
  not resource.change.after.tags
  msg := sprintf("%s is missing tags", [resource.address])
}
