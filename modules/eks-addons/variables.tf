variable "cluster_name" {
  type        = string
  description = "Nome do cluster EKS"
}

variable "lbc_role_arn" {
  type        = string
  description = "ARN da IAM Role IRSA para o AWS Load Balancer Controller"
}

variable "cluster_autoscaler_role_arn" {
  type        = string
  description = "ARN da IAM Role IRSA para o Cluster Autoscaler"
}

variable "datadog_api_key" {
  type        = string
  sensitive   = true
  description = "Datadog API Key"
}

variable "eso_irsa_role_arn" {
  type        = string
  description = "ARN da IAM Role IRSA para o External Secrets Operator"
}
