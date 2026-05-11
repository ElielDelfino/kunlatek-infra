# -------------------------------------------------------
# Secrets Manager — segredos da aplicação
# -------------------------------------------------------

resource "aws_secretsmanager_secret" "app" {
  name                    = "kunlatek/app"
  description             = "Secrets da aplicação kunlatek-api"
  recovery_window_in_days = 0 # permite deletar imediatamente (estudo)
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    DATABASE_URL            = "mysql://${var.db_username}:${var.db_password}@${module.database.db_endpoint}/${var.db_name}"
    JWT_SECRET              = var.jwt_secret
    DATADOG_API_KEY         = var.datadog_api_key
    GCS_PROJECT_ID          = var.gcs_project_id
    GCS_PUBLIC_BUCKET_NAME  = var.gcs_public_bucket_name
    GCS_PRIVATE_BUCKET_NAME = var.gcs_private_bucket_name
    GCS_CREDENTIALS         = var.gcs_credentials
  })
}
