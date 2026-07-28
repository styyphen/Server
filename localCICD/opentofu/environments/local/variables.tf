variable "project_name" {
  description = "Project or service name."
  type        = string
  default     = "sample-service"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "local"
}
