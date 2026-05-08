# Infraestrutura — Desafio DevOps

Infraestrutura AWS provisionada com Terraform para uma aplicação containerizada com backend Node.js, proxy Nginx e banco de dados PostgreSQL, rodando em ECS (EC2 launch type).

## Arquivos `.tf` na raiz

### `backend.tf`
Configura o backend remoto do Terraform. O estado (`terraform.tfstate`) é armazenado em um bucket S3 com criptografia habilitada, evitando conflitos em execuções paralelas e preservando o histórico de mudanças.

### `main.tf`
Ponto de entrada da infraestrutura. Define o provider AWS e instancia os cinco módulos na ordem correta, passando os outputs de um módulo como inputs de outro (ex: `module.network.vpc_id` → `module.compute`).

### `variables.tf`
Declara todas as variáveis de entrada do projeto raiz: região, configurações de rede, banco de dados, ECS, nome da aplicação, JWT secret e tag de imagem.

### `output.tf`
Expõe os valores mais relevantes após o `terraform apply`: ID da VPC, subnets privadas, endpoint do RDS, IDs do cluster/serviço ECS, DNS do ALB e URLs dos repositórios ECR.

## Módulos

| Módulo | Caminho | Descrição resumida |
|---|---|---|
| network | `modules/network` | VPC, subnets públicas/privadas, IGW, NAT Gateway |
| database | `modules/database` | RDS PostgreSQL 16.3 nas subnets privadas |
| iam | `modules/iam` | Roles e instance profile para ECS |
| ecr | `modules/ecr` | Repositórios Docker para backend e Nginx |
| compute | `modules/compute` | ECS Cluster, ASG, ALB, Task Definition e Service |

Cada módulo possui seu próprio `README.md` com detalhes dos recursos, variáveis e outputs.

## Ordem de Deploy (Primeira vez)

O ECS precisa das imagens no ECR antes de subir o serviço. Por isso o deploy inicial segue três passos:

**Passo 1 — Subir ECR e IAM**
```bash
terraform init
terraform apply -var-file="env/dev.tfvars" -target=module.ecr -target=module.iam
```

**Passo 2 — Fazer push das imagens**

Acesse o repositório da aplicação (`app-desafiodevops`) e dispare o workflow manualmente via GitHub Actions (`workflow_dispatch`). Ao final, copie o SHA do commit usado no build (visível nos logs ou na URL do run).

**Passo 3 — Subir o restante da infra**

Edite `env/dev.tfvars` e substitua `initial_image_tag` pelo SHA copiado no passo anterior:

```hcl
initial_image_tag = "abc1234..."  # SHA do commit do primeiro build
```

Depois aplique:
```bash
terraform apply -var-file="env/dev.tfvars"
```

A partir daqui, novos deploys são feitos exclusivamente pelo workflow da aplicação, sem necessidade de rodar o Terraform novamente.

## Ambiente

As variáveis de ambiente são definidas em `env/dev.tfvars`. Para aplicar:

```bash
terraform init
terraform apply -var-file="env/dev.tfvars"
```

## CI/CD

O workflow `.github/workflows/terraform.yaml` automatiza o `terraform plan` e `apply` via GitHub Actions.
