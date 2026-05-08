# Módulo: ecr

Provisiona os repositórios de imagens Docker no Amazon ECR para a aplicação.

## Recursos criados

| Recurso | Descrição |
|---|---|
| `aws_ecr_repository` (backend) | Repositório ECR para a imagem do backend |
| `aws_ecr_repository` (nginx) | Repositório ECR para a imagem do Nginx (proxy reverso) |
| `aws_ecr_lifecycle_policy` (backend) | Política de ciclo de vida: mantém apenas as últimas 10 imagens |
| `aws_ecr_lifecycle_policy` (nginx) | Política de ciclo de vida: mantém apenas as últimas 10 imagens |

## Propósito

Cria os repositórios privados onde as imagens Docker são armazenadas antes de serem implantadas no ECS. O scan automático de vulnerabilidades é habilitado em cada push. As políticas de lifecycle evitam acúmulo de imagens antigas, mantendo no máximo 10 por repositório.

## Variáveis

| Nome | Tipo | Padrão | Descrição |
|---|---|---|---|
| `app_name` | string | `"my-app"` | Prefixo dos repositórios (ex: `my-app-backend`, `my-app-nginx`) |

## Outputs

| Nome | Descrição |
|---|---|
| `backend_repository_url` | URL do repositório ECR do backend |
| `backend_repository_arn` | ARN do repositório ECR do backend |
| `nginx_repository_url` | URL do repositório ECR do Nginx |
| `nginx_repository_arn` | ARN do repositório ECR do Nginx |
