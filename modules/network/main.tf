resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "main-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "igw" }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets_cidr)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets_cidr[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "public-subnet-${count.index}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets_cidr)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets_cidr[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name                                        = "private-subnet-${count.index}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "public-rt" }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "nat" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "private-rt" }
}

resource "aws_route" "private_nat_access" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# -------------------------------------------------------
# Default resources — importados para evitar drift
# -------------------------------------------------------

resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.this.default_network_acl_id

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = { Name = "default" }
}

resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.this.default_route_table_id
  tags                   = { Name = "default" }
}

# Default SG sem regras — boa prática de segurança
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "default" }
}

# Remove ALBs/NLBs órfãos criados pelo LBC que sobrevivem à deleção do cluster EKS
# quando o Ingress/Service não é deletado antes do cluster ser destruído
resource "null_resource" "cleanup_lbc_load_balancers" {
  triggers = {
    vpc_id = aws_vpc.this.id
  }

  # Durante o destroy: cleanup_lbc_load_balancers é destruído ANTES de cleanup_lbc_security_groups
  # (ALBs primeiro → libera SGs → então SGs podem ser deletados)
  # e ANTES do IGW e subnets
  depends_on = [
    null_resource.cleanup_lbc_security_groups,
    aws_internet_gateway.igw,
    aws_subnet.public,
    aws_subnet.private,
  ]

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Removendo ALBs/NLBs órfãos na VPC ${self.triggers.vpc_id}..."
      ALL_ARNS=$(aws elbv2 describe-load-balancers \
        --query "LoadBalancers[?VpcId=='${self.triggers.vpc_id}'].LoadBalancerArn" \
        --output text --region us-east-1)
      for ARN in $ALL_ARNS; do
        echo "Deletando LB: $ARN"
        aws elbv2 delete-load-balancer --load-balancer-arn "$ARN" --region us-east-1 || true
      done
      if [ -n "$ALL_ARNS" ]; then
        echo "Aguardando ENIs de LBs serem liberadas..."
        until [ -z "$(aws ec2 describe-network-interfaces \
          --filters \
            "Name=vpc-id,Values=${self.triggers.vpc_id}" \
            "Name=description,Values=ELB*" \
          --query "NetworkInterfaces[].NetworkInterfaceId" \
          --output text --region us-east-1)" ]; do
          sleep 5
        done
      fi
      echo "Limpeza de ALBs/NLBs concluída."
    EOT
  }
}

# Remove SGs criados dinamicamente pelo AWS Load Balancer Controller (k8s-*)
# Esses SGs não são gerenciados pelo Terraform e bloqueiam a deleção da VPC
resource "null_resource" "cleanup_lbc_security_groups" {
  triggers = {
    vpc_id       = aws_vpc.this.id
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Removendo SGs do LBC na VPC ${self.triggers.vpc_id}..."
      SG_IDS=$(aws ec2 describe-security-groups \
        --filters \
          "Name=vpc-id,Values=${self.triggers.vpc_id}" \
          "Name=tag-key,Values=kubernetes.io/cluster/${self.triggers.cluster_name}" \
        --query "SecurityGroups[].GroupId" \
        --output text \
        --region us-east-1)
      for SG_ID in $SG_IDS; do
        echo "Deletando SG: $SG_ID"
        aws ec2 delete-security-group --group-id $SG_ID --region us-east-1 2>/dev/null || true
      done
      # SGs com prefixo k8s- criados pelo LBC sem tag de cluster
      SG_IDS_K8S=$(aws ec2 describe-security-groups \
        --filters \
          "Name=vpc-id,Values=${self.triggers.vpc_id}" \
          "Name=group-name,Values=k8s-*" \
        --query "SecurityGroups[].GroupId" \
        --output text \
        --region us-east-1)
      for SG_ID in $SG_IDS_K8S; do
        echo "Deletando SG k8s-*: $SG_ID"
        aws ec2 delete-security-group --group-id $SG_ID --region us-east-1 2>/dev/null || true
      done
      echo "Limpeza concluída."
    EOT
  }
}
