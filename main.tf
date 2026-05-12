terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.39"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.datadoghq.com/"
}

provider "kubernetes" {
  host                   = try(module.eks.cluster_endpoint, "")
  cluster_ca_certificate = try(base64decode(module.eks.cluster_ca_data), "")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = try(module.eks.cluster_endpoint, "")
    cluster_ca_certificate = try(base64decode(module.eks.cluster_ca_data), "")

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

module "network" {
  source               = "./modules/network"
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnets_cidr  = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr
  cluster_name         = var.eks_cluster_name
}

module "database" {
  source                    = "./modules/database"
  vpc_id                    = module.network.vpc_id
  private_subnet_ids        = module.network.private_subnet_ids
  db_name                   = var.db_name
  db_username               = var.db_username
  db_password               = var.db_password
  db_instance_type          = var.db_instance_type
  db_allocated_storage      = var.db_allocated_storage
  allowed_cidr_blocks       = [var.vpc_cidr]
  node_security_group_id    = module.eks.node_security_group_id
  cluster_security_group_id = module.eks.cluster_security_group_id
  eks_cluster_name          = var.eks_cluster_name

  depends_on = [module.eks]
}

module "ecr" {
  source   = "./modules/ecr"
  app_name = var.app_name
}

module "eks_kms" {
  source       = "./modules/eks-kms"
  cluster_name = var.eks_cluster_name
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.eks_cluster_name
  vpc_id             = module.network.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = module.network.private_subnet_ids
  public_subnet_ids  = module.network.public_subnet_ids
  kms_key_arn        = module.eks_kms.key_arn
  node_instance_types = var.eks_node_instance_types
  desired_size        = var.eks_desired_size
  min_size            = var.eks_min_size
  max_size            = var.eks_max_size
  infra_desired_size  = var.eks_infra_desired_size
  infra_min_size      = var.eks_infra_min_size
  infra_max_size      = var.eks_infra_max_size
  admin_iam_arn           = var.eks_admin_iam_arn
  admin_iam_arn_2         = var.eks_admin_iam_arn_2
  github_actions_role_arn = var.eks_github_actions_role_arn
}

module "irsa_ebs_csi" {
  source            = "./modules/irsa-ebs-csi"
  cluster_name      = var.eks_cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer       = module.eks.oidc_issuer
}

module "sqs_worker" {
  source = "./modules/sqs-worker"
  name   = "${var.eks_cluster_name}-worker"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = module.irsa_ebs_csi.role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_addon.vpc_cni]
}

module "eks_addons" {
  source = "./modules/eks-addons"

  cluster_name                = module.eks.cluster_name
  lbc_role_arn                = module.eks.lbc_role_arn
  cluster_autoscaler_role_arn = module.eks.cluster_autoscaler_role_arn
  datadog_api_key             = var.datadog_api_key
  eso_irsa_role_arn           = aws_iam_role.eso.arn

  depends_on = [module.eks, aws_eks_addon.ebs_csi, aws_eks_addon.vpc_cni]
}
