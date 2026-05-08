# SG automático criado pelo EKS e associado aos nodes
data "aws_security_group" "eks_auto" {
  filter {
    name   = "tag:aws:eks:cluster-name"
    values = [var.eks_cluster_name]
  }
}

resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "Security group for database"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.node_security_group_id, var.cluster_security_group_id, data.aws_security_group.eks_auto.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "db-sg" }
}

resource "aws_db_subnet_group" "this" {
  name       = "db-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "this" {
  identifier             = "app-mysql"
  allocated_storage      = var.db_allocated_storage
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_type
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  apply_immediately      = true
  skip_final_snapshot    = true
  multi_az               = false  # free tier não suporta Multi-AZ
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  deletion_protection    = false
  publicly_accessible    = false
  backup_retention_period = 0     # free tier não suporta retention > 0
  auto_minor_version_upgrade = true

  tags = { Name = "app-mysql-db" }
}