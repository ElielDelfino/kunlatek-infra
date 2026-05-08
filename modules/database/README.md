# Módulo: database

Provisiona o banco de dados PostgreSQL gerenciado (RDS) nas subnets privadas.

## Recursos criados

| Recurso | Descrição |
|---|---|
| `aws_security_group` (db) | Security group que libera a porta 5432 apenas para CIDRs internos da VPC |
| `aws_db_subnet_group` | Subnet group associando o RDS às subnets privadas |
| `aws_db_instance` | Instância RDS PostgreSQL 16.3 |

## Propósito

Cria um banco de dados PostgreSQL acessível apenas internamente pela VPC (não exposto à internet). Utilizado pelo backend da aplicação via variável de ambiente `POSTGRES_URI`. A instância fica nas subnets privadas e aceita conexões somente na porta 5432 a partir dos CIDRs permitidos.

## Variáveis

| Nome | Tipo | Descrição |
|---|---|---|
| `vpc_id` | string | ID da VPC |
| `private_subnet_ids` | list(string) | Subnets privadas para o RDS |
| `db_name` | string | Nome do banco de dados |
| `db_username` | string | Usuário do banco |
| `db_password` | string | Senha do banco |
| `db_instance_type` | string | Tipo da instância RDS (ex: `db.t3.micro`) |
| `db_allocated_storage` | number | Armazenamento em GB |
| `allowed_cidr_blocks` | list(string) | CIDRs com acesso à porta 5432 |

## Outputs

| Nome | Descrição |
|---|---|
| `db_endpoint` | Endpoint de conexão do RDS |
| `db_port` | Porta do banco (5432) |
| `db_identifier` | Identificador da instância RDS |
| `db_security_group_id` | ID do security group do banco |
