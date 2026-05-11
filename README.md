# infra-desafiodevops

Infraestrutura AWS provisionada com Terraform para aplicação NestJS rodando em EKS com MySQL RDS.

## Estrutura

```
infra-desafiodevops/
├── main.tf           # providers e chamada dos módulos
├── variables.tf      # variáveis de entrada (sem defaults para valores sensíveis)
├── output.tf         # outputs expostos para o k8s-desafiodevops
├── secrets.tf               # AWS Secrets Manager (kunlatek/app)
├── datadog-observability.tf # Dashboard e monitors do Datadog
├── iam.tf                   # Service-linked roles + IRSA roles (app e ESO)
├── backend.tf        # estado remoto no S3
├── env/
│   └── dev.tfvars   # valores do ambiente dev (não commitado — coberto pelo .gitignore)
└── modules/
    ├── network/      # VPC, subnets, IGW, NAT Gateway
    ├── eks/          # cluster EKS, node group SPOT, OIDC, IAM roles
    ├── eks-kms/      # KMS key para criptografia dos secrets do cluster
    ├── eks-addons/   # Helm charts: LBC, ESO, Autoscaler, Datadog, Metrics Server, ArgoCD, Argo Rollouts
    ├── database/     # RDS MySQL nas subnets privadas
    ├── ecr/          # repositório ECR da aplicação
    ├── irsa-ebs-csi/ # IRSA para o EBS CSI Driver
    └── sqs-worker/   # fila SQS principal + DLQ
```

## Módulos

| Módulo | Descrição |
|---|---|
| `network` | VPC, subnets públicas/privadas, IGW, NAT Gateway |
| `eks` | Cluster EKS 1.31, node group SPOT AL2023 com ENI prefix delegation (110 pods/node), OIDC provider, IAM roles (LBC, Autoscaler) |
| `eks-kms` | KMS customer-managed key para criptografia dos secrets do Kubernetes |
| `eks-addons` | AWS Load Balancer Controller, External Secrets Operator (com IRSA), Cluster Autoscaler, Datadog Agent, Metrics Server, ArgoCD, Argo Rollouts |
| `database` | RDS MySQL t3.micro nas subnets privadas |
| `ecr` | Repositório ECR para imagens da aplicação |
| `irsa-ebs-csi` | IAM Role para o EBS CSI Driver (volumes persistentes) |
| `sqs-worker` | Fila SQS com DLQ para processamento assíncrono |

## IAM Roles IRSA

Todos os recursos IAM estão em `iam.tf`.

| Recurso | Tipo | Criada por |
|---|---|---|
| `aws_iam_service_linked_role.elb` | Service-linked | AWS Load Balancer Controller ao criar o primeiro ALB |
| `aws_iam_service_linked_role.eks` | Service-linked | Criação do cluster EKS |
| `aws_iam_service_linked_role.eks_nodegroup` | Service-linked | Criação do managed node group |
| `aws_iam_service_linked_role.autoscaling` | Service-linked | Auto Scaling Group do node group |
| `aws_iam_service_linked_role.ec2_spot` | Service-linked | Uso de instâncias SPOT |
| `aws_iam_service_linked_role.rds` | Service-linked | Criação da instância RDS |
| `aws_iam_role.app_sa` | IRSA — `kunlatek/kunlatek-api-sa` | `secretsmanager:GetSecretValue`, SQS da fila da app |
| `aws_iam_role.eso` | IRSA — `external-secrets/external-secrets` | `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret` |

O ESO usa sua própria role para sincronizar `kunlatek/app` do Secrets Manager como K8s Secret. A `app_sa` é usada pelos pods para acesso direto ao SQS.

### Service-linked roles — import em conta com recursos existentes

Se a conta AWS já tiver as roles (criadas por uso anterior de qualquer serviço), importe antes do `apply`:

```bash
terraform import aws_iam_service_linked_role.elb \
  arn:aws:iam::890871562295:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing

terraform import aws_iam_service_linked_role.eks \
  arn:aws:iam::890871562295:role/aws-service-role/eks.amazonaws.com/AWSServiceRoleForAmazonEKS

terraform import aws_iam_service_linked_role.eks_nodegroup \
  arn:aws:iam::890871562295:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup

terraform import aws_iam_service_linked_role.autoscaling \
  arn:aws:iam::890871562295:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling

terraform import aws_iam_service_linked_role.ec2_spot \
  arn:aws:iam::890871562295:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot

terraform import aws_iam_service_linked_role.rds \
  arn:aws:iam::890871562295:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS
```

## Secrets Manager

O secret `kunlatek/app` contém:

| Chave | Origem |
|---|---|
| `DATABASE_URL` | composta de `db_username`, `db_password` e endpoint do RDS |
| `JWT_SECRET` | variável `jwt_secret` |
| `DATADOG_API_KEY` | variável `datadog_api_key` |
| `GCS_PROJECT_ID` | variável `gcs_project_id` |
| `GCS_PUBLIC_BUCKET_NAME` | variável `gcs_public_bucket_name` |
| `GCS_PRIVATE_BUCKET_NAME` | variável `gcs_private_bucket_name` |
| `GCS_CREDENTIALS` | variável `gcs_credentials` |

> `SQS_WORKER_URL` não é armazenada como secret — é uma configuração injetada via ConfigMap pelo pipeline de deploy.

## Capacidade de pods por node

Os nodes usam `t3.small` com **ENI Prefix Delegation** ativo, o que altera a capacidade assim:

| | Padrão (sem prefix delegation) | Com prefix delegation |
|---|---|---|
| IPs por node | 9 | 144 |
| Pods por node | 11 | **110** |
| Pods totais (3 nodes) | 33 | **330** |

A combinação de duas configurações garante isso:

- **VPC CNI** (`aws_eks_addon.vpc_cni`): `ENABLE_PREFIX_DELEGATION=true` — aloca blocos `/28` (16 IPs) por slot de ENI em vez de 1 IP
- **Launch template** (`modules/eks`): `nodeadm` user data com `maxPods: 110` + `ami_type = AL2023_x86_64_STANDARD` — informa ao kubelet o novo limite; sem isso o kubelet continuaria rejeitando pods acima de 11 mesmo com o CNI configurado

## Deploy

O deploy usa um `Makefile` que encapsula os 3 stages necessários em um único comando. Os providers `helm` e `kubernetes` precisam do cluster pronto antes de inicializar — por isso o apply não pode ser feito em uma única chamada direta ao Terraform.

### Comandos

```bash
make init       # terraform init -upgrade
make apply      # roda os 3 stages na ordem correta automaticamente
make plan       # terraform plan completo
make destroy    # terraform destroy
```

### O que o `make apply` faz internamente

| Stage | O que sobe |
|---|---|
| 1 | Service-linked roles, VPC, EKS, RDS, ECR, SQS, EKS addons nativos (vpc-cni, ebs-csi), Secrets Manager, IAM IRSA |
| 2 | Helm charts via `module.eks_addons` (LBC, ESO, Autoscaler, Datadog Agent, ArgoCD, Argo Rollouts) |
| 3 | Apply completo — Datadog dashboards/monitors e qualquer recurso restante |

### Service-linked roles — se já existirem na conta

Se o apply falhar com `already exists` nas service-linked roles (conta usada anteriormente), importe antes de rodar `make apply`:

```bash
make import-slr
```

## Variáveis obrigatórias

As variáveis abaixo não possuem `default` — o Terraform recusa o apply se não forem fornecidas.

| Variável | Descrição |
|---|---|
| `eks_admin_iam_arn` | ARN do usuário/role IAM com acesso admin ao cluster |
| `eks_github_actions_role_arn` | ARN da role usada pelo GitHub Actions para deploy |
| `db_password` | Senha do banco de dados |
| `jwt_secret` | Secret para geração de tokens JWT |
| `datadog_api_key` | Datadog API Key (usada pelo Agent no cluster e pelo provider) |
| `datadog_app_key` | Datadog Application Key (necessária para criar dashboards e monitors) |

Coloque os valores em `env/dev.tfvars` (já no `.gitignore`) e passe com `-var-file=env/dev.tfvars`.

## CI/CD

O workflow `.github/workflows/terraform.yaml` executa via GitHub Actions com OIDC (sem credenciais estáticas). As variáveis sensíveis são injetadas como `TF_VAR_*` a partir dos secrets do repositório.

| Secret do repositório | Variável Terraform |
|---|---|
| `TF_VAR_EKS_ADMIN_IAM_ARN` | `eks_admin_iam_arn` |
| `TF_VAR_EKS_GITHUB_ACTIONS_ROLE_ARN` | `eks_github_actions_role_arn` |
| `TF_VAR_DB_PASSWORD` | `db_password` |
| `TF_VAR_JWT_SECRET` | `jwt_secret` |
| `TF_VAR_DATADOG_API_KEY` | `datadog_api_key` |
| `TF_VAR_DATADOG_APP_KEY` | `datadog_app_key` |

> A pasta `k8s-desafiodevops/` foi consolidada aqui — o provider Datadog, dashboard e monitors agora fazem parte do mesmo state da infra, eliminando a dependência de `terraform_remote_state`.

❯ kubectl exec -n datadog datadog-cluster-agent-5f589c7bbc-vc8g2 -- agent health
