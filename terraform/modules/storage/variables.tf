variable "name" {
  description = "Globally unique S3 bucket name."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
