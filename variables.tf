variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnets_cidr" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets_cidr" {
  type    = list(string)
  default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_instance_type" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "app_name" {
  type    = string
  default = "kunlatek-app"
}

variable "eks_cluster_name" {
  type    = string
  default = "kunlatek-eks"
}

variable "eks_node_instance_types" {
  type    = list(string)
  default = ["t3.small", "t3a.small"]
}

variable "eks_desired_size" {
  type    = number
  default = 4
}

variable "eks_min_size" {
  type    = number
  default = 3
}

variable "eks_max_size" {
  type    = number
  default = 4
}

variable "eks_infra_desired_size" {
  type    = number
  default = 2
}

variable "eks_infra_min_size" {
  type    = number
  default = 2
}

variable "eks_infra_max_size" {
  type    = number
  default = 3
}

variable "eks_admin_iam_arn" {
  type = string
}

variable "eks_github_actions_role_arn" {
  type        = string
  description = "ARN da role IAM usada pelo GitHub Actions para deploy no EKS"
}

variable "eks_admin_iam_arn_2" {
  type        = string
  description = "ARN do segundo usuário IAM com acesso de admin ao cluster EKS"
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "datadog_api_key" {
  type        = string
  sensitive   = true
  description = "Datadog API Key"
}

variable "datadog_app_key" {
  type        = string
  sensitive   = true
  description = "Datadog Application Key (necessária para gerenciar dashboards e monitors)"
}

variable "gcs_project_id" {
  type    = string
  default = ""
}

variable "gcs_public_bucket_name" {
  type    = string
  default = "teste-public"
}

variable "gcs_private_bucket_name" {
  type    = string
  default = "test-private"
}

variable "gcs_credentials" {
  type      = string
  sensitive = true
  default   = "{}"
}
