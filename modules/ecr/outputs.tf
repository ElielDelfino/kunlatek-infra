output "backend_repository_url" {
  description = "URL do repositório ECR para backend"
  value       = aws_ecr_repository.backend.repository_url
}

output "backend_repository_arn" {
  description = "ARN do repositório ECR para backend"
  value       = aws_ecr_repository.backend.arn
}
