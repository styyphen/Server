variable "name" {
  description = "Logical database name."
  type        = string
}

variable "engine" {
  description = "Database engine label."
  type        = string
  default     = "document"
}
