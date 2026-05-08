output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "rds_endpoint" {
  value     = module.database.db_endpoint
  sensitive = true
}

output "ecr_backend_repository_url" {
  value = module.ecr.backend_repository_url
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}

output "eks_lbc_role_arn" {
  value = module.eks.lbc_role_arn
}

output "eks_kms_key_arn" {
  value = module.eks_kms.key_arn
}

output "ebs_csi_role_arn" {
  value = module.irsa_ebs_csi.role_arn
}

output "secrets_csi_role_arn" {
  value = aws_iam_role.secrets_csi.arn
}

output "app_secret_arn" {
  value = aws_secretsmanager_secret.app.arn
}

output "eks_cluster_autoscaler_role_arn" {
  value = module.eks.cluster_autoscaler_role_arn
}

output "sqs_worker_url" {
  value = aws_sqs_queue.worker.url
}

output "sqs_worker_arn" {
  value = aws_sqs_queue.worker.arn
}
