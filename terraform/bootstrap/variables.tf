variable "aws_region" {
  description = "AWS region for the state resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource names."
  type        = string
  default     = "production-platform-simulation"
}

variable "github_repository" {
  description = "GitHub repository in owner/name form."
  type        = string
  default     = "pfoseh-ops/production-platform-simulation"
}

variable "state_bucket_name" {
  description = "Globally unique Terraform state bucket name."
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table used for Terraform state locking."
  type        = string
  default     = "production-platform-simulation-tf-locks"
}
