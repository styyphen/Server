output "storage" {
  description = "Local storage resources."
  value = {
    artifacts = module.artifacts.name
    uploads   = module.uploads.name
  }
}

output "queue" {
  description = "Local queue resources."
  value = {
    name            = module.events.name
    deadletter_name = module.events.deadletter_name
  }
}

output "database" {
  description = "Local database resource."
  value = {
    name   = module.state.name
    engine = module.state.engine
  }
}
