# -------------------------------------------------------
# IRSA — locals compartilhado
# -------------------------------------------------------

locals {
  oidc_issuer_clean = replace(module.eks.oidc_issuer, "https://", "")
}

# -------------------------------------------------------
# IRSA — IAM Role da Service Account da aplicação
# Permissões: Secrets Manager + SQS
# -------------------------------------------------------

resource "aws_iam_role" "app_sa" {
  name = "${var.eks_cluster_name}-app-sa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer_clean}:sub" = "system:serviceaccount:kunlatek:kunlatek-api-sa"
          "${local.oidc_issuer_clean}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "app_sa_secrets" {
  name = "${var.eks_cluster_name}-app-sa-secrets"
  role = aws_iam_role.app_sa.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = aws_secretsmanager_secret.app.arn
    }]
  })
}

resource "aws_iam_role_policy" "app_sa_sqs" {
  name = "${var.eks_cluster_name}-app-sa-sqs"
  role = aws_iam_role.app_sa.name

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
        module.sqs_worker.queue_arn,
        module.sqs_worker.dlq_arn
      ]
    }]
  })
}

# -------------------------------------------------------
# IRSA — IAM Role do External Secrets Operator
# Permissões: apenas leitura no Secrets Manager
# -------------------------------------------------------

resource "aws_iam_role" "eso" {
  name = "${var.eks_cluster_name}-eso-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer_clean}:sub" = "system:serviceaccount:external-secrets:external-secrets"
          "${local.oidc_issuer_clean}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "eso_secrets" {
  name = "${var.eks_cluster_name}-eso-secrets"
  role = aws_iam_role.eso.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = aws_secretsmanager_secret.app.arn
    }]
  })
}
