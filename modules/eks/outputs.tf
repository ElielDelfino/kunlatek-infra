output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_issuer" {
  value = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "lbc_role_arn" {
  value = aws_iam_role.lbc.arn
}

output "node_role_arn" {
  value = aws_iam_role.node.arn
}

output "node_security_group_id" {
  value = aws_security_group.node.id
}

output "cluster_security_group_id" {
  value = aws_security_group.cluster.id
}

output "cluster_autoscaler_role_arn" {
  value = aws_iam_role.cluster_autoscaler.arn
}
