variable "aws_region"           { type = string }
variable "vpc_cidr"             { type = string }
variable "azs"                  { type = list(string) }
variable "public_subnets_cidr"  { type = list(string) }
variable "private_subnets_cidr" { type = list(string) }
variable "db_name"              { type = string }
variable "db_username"          { type = string }
variable "db_password"          { type = string }
variable "db_instance_type"     { type = string }
variable "db_allocated_storage" { type = number }
variable "app_name"             { type = string }

variable "eks_cluster_name" {
  type    = string
  default = "my-eks-cluster"
}

variable "eks_node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "eks_desired_size" {
  type    = number
  default = 2
}

variable "eks_min_size" {
  type    = number
  default = 1
}

variable "eks_max_size" {
  type    = number
  default = 4
}

variable "eks_admin_iam_arn" {
  type = string
}

variable "jwt_secret" {
  type      = string
  sensitive = true
  default   = "change_me_in_production"
}

variable "datadog_api_key" {
  type      = string
  sensitive = true
  description = "Datadog API Key"
}

variable "gcs_project_id" {
  type    = string
  default = ""
}

variable "gcs_public_bucket_name" {
  type    = string
  default = ""
}

variable "gcs_private_bucket_name" {
  type    = string
  default = ""
}

variable "gcs_credentials" {
  type      = string
  sensitive = true
  default   = ""
}