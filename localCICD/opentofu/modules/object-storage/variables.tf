variable "name" {
  description = "Logical storage container name."
  type        = string
}

variable "provider_name" {
  description = "Target provider label used by the local plan."
  type        = string
  default     = "local"
}
