variable "cluster_name"       { type = string }
variable "vpc_id"             { type = string }
variable "vpc_cidr"           { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids"  { type = list(string) }
variable "kms_key_arn"        { type = string }
variable "admin_iam_arn"      { type = string }

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.small", "t3a.small"]
}

variable "desired_size" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 4
}
variable "github_actions_role_arn" {
  type        = string
  description = "ARN da role IAM usada pelo GitHub Actions para deploy no EKS"
}

variable "admin_iam_arn_2" {
  type        = string
  description = "ARN do segundo usuário IAM com acesso de admin ao cluster EKS"
}

variable "infra_desired_size" {
  type    = number
  default = 2
}

variable "infra_min_size" {
  type    = number
  default = 2
}

variable "infra_max_size" {
  type    = number
  default = 3
}
