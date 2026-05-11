output "queue_url" {
  value       = aws_sqs_queue.main.url
  description = "URL da fila principal"
}

output "queue_arn" {
  value       = aws_sqs_queue.main.arn
  description = "ARN da fila principal"
}

output "dlq_arn" {
  value       = aws_sqs_queue.dlq.arn
  description = "ARN da Dead Letter Queue"
}
