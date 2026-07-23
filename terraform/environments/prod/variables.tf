variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "project_name" {
  type    = string
  default = "production-platform-simulation"
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "kubernetes_version" {
  description = "A Kubernetes version currently supported by EKS."
  type        = string
  default     = "1.31"
}

variable "public_access_cidrs" {
  description = "Trusted CIDRs allowed to access the EKS public API."
  type        = list(string)

  validation {
    condition     = length(var.public_access_cidrs) > 0 && !contains(var.public_access_cidrs, "0.0.0.0/0")
    error_message = "Set at least one trusted CIDR; 0.0.0.0/0 is prohibited."
  }
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "image_repository" {
  description = "Container image repository, without the tag."
  type        = string
  default     = "ghcr.io/pfoseh-ops/production-platform-simulation"
}

variable "image_tag" {
  description = "Immutable container tag, normally the Git commit SHA."
  type        = string
  default     = "latest"
}

variable "grafana_admin_password" {
  description = "Grafana admin password."
  type        = string
  sensitive   = true
}
