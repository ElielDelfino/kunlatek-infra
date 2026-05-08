# Dead-letter queue — recebe mensagens que falharam 3x
resource "aws_sqs_queue" "worker_dlq" {
  name                      = "${var.eks_cluster_name}-worker-dlq"
  message_retention_seconds = 1209600 # 14 dias
}

# Fila principal
resource "aws_sqs_queue" "worker" {
  name                       = "${var.eks_cluster_name}-worker"
  visibility_timeout_seconds = 60  # maior que o tempo máximo de processamento
  message_retention_seconds  = 86400 # 1 dia
  receive_wait_time_seconds  = 5    # long polling — reduz chamadas vazias

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.worker_dlq.arn
    maxReceiveCount     = 3
  })
}

# Permissão SQS adicionada na role existente da API (kunlatek-eks-secrets-csi-role)
resource "aws_iam_role_policy" "api_sa_sqs" {
  name = "${var.eks_cluster_name}-api-sa-sqs"
  role = aws_iam_role.secrets_csi.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = [
        aws_sqs_queue.worker.arn,
        aws_sqs_queue.worker_dlq.arn
      ]
    }]
  })
}
