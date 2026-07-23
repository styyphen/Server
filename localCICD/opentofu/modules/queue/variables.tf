variable "name" {
  description = "Logical queue name."
  type        = string
}

variable "deadletter_enabled" {
  description = "Whether a dead-letter queue should be provisioned."
  type        = bool
  default     = true
}
