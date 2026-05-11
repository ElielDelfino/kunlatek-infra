# kunlatek-infra

Infraestrutura AWS provisionada com Terraform para a API Kunlatek rodando em EKS com MySQL RDS.

## Estrutura

```
kunlatek-infra/
├── main.tf                  # providers e chamada dos módulos
├── variables.tf             # variáveis de entrada (sem defaults para valores sensíveis)
├── output.tf                # outputs do state
├── secrets.tf               # AWS Secrets Manager (kunlatek/app)
├── datadog-observability.tf # dashboard e monitors do Datadog
├── iam.tf                   # service-linked roles + IRSA roles (app e ESO)
├── Makefile                 # atalhos para init / plan / apply em stages
├── env/
│   └── dev.tfvars           # valores do ambiente dev (não commitado — coberto pelo .gitignore)
└── modules/
    ├── network/             # VPC, subnets, IGW, NAT Gateway
    ├── eks/                 # cluster EKS, node groups SPOT, OIDC, IAM roles
    ├── eks-kms/             # KMS key para criptografia dos secrets do cluster
    ├── eks-addons/          # Helm charts: LBC, ESO, Autoscaler, Datadog, Metrics Server, ArgoCD, Argo Rollouts
    ├── database/            # RDS MySQL nas subnets privadas
    ├── ecr/                 # repositório ECR da aplicação
    ├── irsa-ebs-csi/        # IRSA para o EBS CSI Driver
    └── sqs-worker/          # fila SQS principal + DLQ
```

## Módulos

| Módulo | Descrição |
|---|---|
| `network` | VPC, subnets públicas/privadas, IGW, NAT Gateway |
| `eks` | Cluster EKS 1.31, dois node groups SPOT AL2023 (infra + app) com ENI prefix delegation (110 pods/node), OIDC provider, IAM roles |
| `eks-kms` | KMS customer-managed key para criptografia dos secrets do Kubernetes |
| `eks-addons` | AWS Load Balancer Controller, External Secrets Operator (com IRSA), Cluster Autoscaler, Datadog Agent, Metrics Server, ArgoCD, Argo Rollouts |
| `database` | RDS MySQL t3.micro nas subnets privadas |
| `ecr` | Repositório ECR para imagens da aplicação |
| `irsa-ebs-csi` | IAM Role para o EBS CSI Driver (volumes persistentes) |
| `sqs-worker` | Fila SQS com DLQ para processamento assíncrono |

## Node Groups — separação infra / app

O cluster usa dois node groups SPOT (`t3.small`) com taints que garantem isolamento de workloads:

| Node Group | Taint | Workloads |
|---|---|---|
| `kunlatek-eks-infra-ng` | `role=infra:NoSchedule` | ArgoCD, Argo Rollouts, Datadog Cluster Agent, ESO, LBC, Cluster Autoscaler, Metrics Server |
| `kunlatek-eks-ng` (app) | `role=app:NoSchedule` | kunlatek-api, kunlatek-worker |

O taint `NoSchedule` impede que pods sem a toleration correspondente aterrisem no node group errado. O Datadog DaemonSet tolera ambos os taints para coletar métricas de todos os nodes.

Variáveis de sizing:

| Variável | Padrão | Node Group |
|---|---|---|
| `eks_desired_size` | 4 | app |
| `eks_min_size` | 3 | app |
| `eks_max_size` | 4 | app |
| `eks_infra_desired_size` | 2 | infra |
| `eks_infra_min_size` | 2 | infra |
| `eks_infra_max_size` | 3 | infra |

## Capacidade de pods por node

Os nodes usam `t3.small` com **ENI Prefix Delegation** ativo:

| | Sem prefix delegation | Com prefix delegation |
|---|---|---|
| IPs por node | 9 | 144 |
| Pods por node | 11 | **110** |

A combinação de duas configurações garante isso:

- **VPC CNI** (`aws_eks_addon.vpc_cni`): `ENABLE_PREFIX_DELEGATION=true` — aloca blocos `/28` por slot de ENI
- **Launch template** (`modules/eks`): `nodeadm` user data com `maxPods: 110` + `ami_type = AL2023_x86_64_STANDARD` — informa ao kubelet o novo limite

## IAM Roles IRSA

Todos os recursos IAM estão em `iam.tf`.

| Recurso | Tipo | Permissões |
|---|---|---|
| `aws_iam_service_linked_role.elb` | Service-linked | AWS Load Balancer Controller |
| `aws_iam_service_linked_role.eks` | Service-linked | Criação do cluster EKS |
| `aws_iam_service_linked_role.eks_nodegroup` | Service-linked | Managed node groups |
| `aws_iam_service_linked_role.autoscaling` | Service-linked | Auto Scaling Group |
| `aws_iam_service_linked_role.ec2_spot` | Service-linked | Instâncias SPOT |
| `aws_iam_service_linked_role.rds` | Service-linked | RDS |
| `aws_iam_role.app_sa` | IRSA — `kunlatek/kunlatek-api-sa` | `secretsmanager:GetSecretValue`, SQS |
| `aws_iam_role.eso` | IRSA — `external-secrets/external-secrets` | `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret` |

### Service-linked roles — import em conta com recursos existentes

Se a conta AWS já tiver as roles (criadas por uso anterior de qualquer serviço), importe antes do `apply`:

```bash
make import-slr
```

Ou manualmente:

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

> `SQS_WORKER_URL` não é armazenada como secret — é injetada via ConfigMap pelo pipeline de deploy.

## Observabilidade — Datadog

Definida em `datadog-observability.tf`. Inclui:

**Dashboard:** `Kunlatek API — Overview` com grupos:
- Status da API: pods running, requisições/s, latência média, taxa de erros
- Uso de Recursos: CPU e memória dos pods, réplicas do HPA
- Nodes do Cluster: CPU e memória por node

**Monitors (alertas):**

| Monitor | Query | Critical | Warning |
|---|---|---|---|
| Alta Latência | `avg:trace.express.request.duration` (últimos 2min) | > 200ms | > 150ms |
| Taxa de Erro | erros / total × 100 (último 1min) | > 1% | > 0.5% |
| CPU Alta nos Nodes | `avg:system.cpu.user` (últimos 5min) | > 80% | > 70% |
| Pods Reiniciando | restarts acumulados por pod (últimos 15min) | > 8 | > 5 |

> O threshold de restarts está calibrado para ambientes SPOT: uma interrupção SPOT típica causa 2–4 restarts em ~2 minutos antes da recuperação automática. O alerta só dispara em problemas reais (OOM loop, deploy quebrado).

## Deploy

### Makefile

```bash
make init       # terraform init -upgrade
make plan       # terraform plan completo
make apply      # roda os 3 stages na ordem correta
make destroy    # terraform destroy
```

### Por que 3 stages?

Os providers `helm` e `kubernetes` precisam do cluster pronto para inicializar. O apply direto falha porque o cluster ainda não existe quando o Terraform tenta configurar esses providers.

| Stage | O que sobe |
|---|---|
| 1 | Service-linked roles, VPC, EKS (cluster + node groups), RDS, ECR, SQS, EKS addons nativos (vpc-cni, ebs-csi), Secrets Manager, IAM IRSA |
| 2 | Helm charts via `module.eks_addons` (LBC, ESO, Autoscaler, Datadog, ArgoCD, Argo Rollouts) |
| 3 | Apply completo — Datadog dashboards/monitors e qualquer recurso restante |

## CI/CD

O workflow `.github/workflows/terraform.yaml` executa via GitHub Actions com OIDC (sem credenciais estáticas). É disparado em todo push para `main` (executa o `plan` automaticamente) e por `workflow_dispatch` para as demais ações.

| Action | Quando roda |
|---|---|
| `plan` | Todo push para `main` (automático) |
| `apply` | Disparo manual via `workflow_dispatch` |
| `plan-destroy` | Disparo manual via `workflow_dispatch` |
| `destroy` | Disparo manual via `workflow_dispatch` |

### Secrets obrigatórios no repositório

| Secret | Variável Terraform |
|---|---|
| `AWS_ROLE_ARN` | Role assumida pelo GitHub Actions via OIDC |
| `TF_VAR_EKS_ADMIN_IAM_ARN` | `eks_admin_iam_arn` — ARN do usuário IAM admin do cluster |
| `TF_VAR_EKS_GITHUB_ACTIONS_ROLE_ARN` | `eks_github_actions_role_arn` |
| `TF_VAR_DB_PASSWORD` | `db_password` |
| `TF_VAR_JWT_SECRET` | `jwt_secret` |
| `TF_VAR_DATADOG_API_KEY` | `datadog_api_key` |
| `TF_VAR_DATADOG_APP_KEY` | `datadog_app_key` |

> `TF_VAR_EKS_ADMIN_IAM_ARN` deve ser o ARN do usuário IAM, não de uma role. Exemplo: `arn:aws:iam::890871562295:user/eliel-delfino`.

## Variáveis obrigatórias

Variáveis sem `default` — o Terraform recusa o apply se não forem fornecidas:

| Variável | Descrição |
|---|---|
| `eks_admin_iam_arn` | ARN do usuário/role IAM com acesso admin ao cluster |
| `eks_github_actions_role_arn` | ARN da role usada pelo GitHub Actions para deploy |
| `db_password` | Senha do banco de dados |
| `jwt_secret` | Secret para geração de tokens JWT |
| `datadog_api_key` | Datadog API Key |
| `datadog_app_key` | Datadog Application Key (necessária para dashboards e monitors) |

Para rodar localmente, coloque os valores em `env/dev.tfvars` (já no `.gitignore`) e passe com `-var-file=env/dev.tfvars`.
