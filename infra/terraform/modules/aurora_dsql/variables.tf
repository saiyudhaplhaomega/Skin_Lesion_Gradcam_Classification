variable "project_name" {
  description = "Project name prefix for all resources (e.g. 'skin-lesion')"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. 'dev', 'staging', 'prod')"
  type        = string
}

variable "deletion_protection" {
  description = "Enable deletion protection on the cluster. Set to true in production."
  type        = bool
  default     = false
}
