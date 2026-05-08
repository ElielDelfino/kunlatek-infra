# -------------------------------------------------------
# Secret no AWS Secrets Manager
# -------------------------------------------------------

resource "aws_secretsmanager_secret" "app" {
  name                    = "kunlatek/app"
  description             = "Secrets da aplicação kunlatek-api"
  recovery_window_in_days = 0 # permite deletar imediatamente (estudo)
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    DATABASE_URL              = "mysql://${var.db_username}:${var.db_password}@${module.database.db_endpoint}/${var.db_name}"
    JWT_SECRET                = var.jwt_secret
    DATADOG_API_KEY           = var.datadog_api_key
    GCS_PROJECT_ID            = var.gcs_project_id
    GCS_PUBLIC_BUCKET_NAME    = var.gcs_public_bucket_name
    GCS_PRIVATE_BUCKET_NAME   = var.gcs_private_bucket_name
    GCS_CREDENTIALS           = var.gcs_credentials
    SQS_WORKER_URL            = aws_sqs_queue.worker.url
  })
}

# -------------------------------------------------------
# IRSA — permite que o CSI Driver leia o Secrets Manager
# -------------------------------------------------------

locals {
  oidc_issuer_clean = replace(module.eks.oidc_issuer, "https://", "")
}

resource "aws_iam_role" "secrets_csi" {
  name = "${var.eks_cluster_name}-secrets-csi-role"

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

resource "aws_iam_role_policy" "secrets_csi" {
  name = "${var.eks_cluster_name}-secrets-csi-policy"
  role = aws_iam_role.secrets_csi.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = aws_secretsmanager_secret.app.arn
    }]
  })
}
