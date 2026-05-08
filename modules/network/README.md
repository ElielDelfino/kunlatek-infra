# Módulo: network

Provisiona a infraestrutura de rede base da aplicação na AWS.

## Recursos criados

| Recurso | Descrição |
|---|---|
| `aws_vpc` | VPC principal com suporte a DNS habilitado |
| `aws_internet_gateway` | Internet Gateway para acesso público |
| `aws_subnet` (public) | Subnets públicas em múltiplas AZs (com IP público automático) |
| `aws_subnet` (private) | Subnets privadas em múltiplas AZs |
| `aws_route_table` (public) | Tabela de rotas pública com rota para o IGW |
| `aws_route_table` (private) | Tabela de rotas privada com rota para o NAT Gateway |
| `aws_eip` | Elastic IP para o NAT Gateway |
| `aws_nat_gateway` | NAT Gateway na subnet pública para saída das subnets privadas |

## Propósito

Cria o isolamento de rede da aplicação. O ALB fica nas subnets públicas (acessível pela internet), enquanto as instâncias ECS e o banco de dados ficam nas subnets privadas (sem acesso direto da internet). O NAT Gateway permite que os recursos privados façam chamadas de saída (ex: pull de imagens do ECR).

## Variáveis

| Nome | Tipo | Descrição |
|---|---|---|
| `vpc_cidr` | string | CIDR block da VPC |
| `azs` | list(string) | Zonas de disponibilidade |
| `public_subnets_cidr` | list(string) | CIDRs das subnets públicas |
| `private_subnets_cidr` | list(string) | CIDRs das subnets privadas |

## Outputs

| Nome | Descrição |
|---|---|
| `vpc_id` | ID da VPC criada |
| `public_subnet_ids` | IDs das subnets públicas |
| `private_subnet_ids` | IDs das subnets privadas |
| `public_subnet_azs` | AZs das subnets públicas |
| `private_subnet_azs` | AZs das subnets privadas |
