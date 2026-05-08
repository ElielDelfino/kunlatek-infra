aws_region           = "us-east-1"
vpc_cidr             = "10.0.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnets_cidr = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
db_name              = "appdb"
db_username          = "appuser"
db_password          = "password123"
db_instance_type     = "db.t3.micro"
db_allocated_storage = 20
app_name             = "kunlatek-app"

eks_cluster_name       = "kunlatek-eks"
eks_node_instance_type = "t3.small"
eks_desired_size       = 3
eks_min_size           = 1
eks_max_size           = 4

eks_admin_iam_arn       = "arn:aws:iam::890871562295:user/eliel-delfino"
datadog_api_key         = "864e12807b34dd93deaf7a828ec19677"
gcs_project_id          = ""
gcs_public_bucket_name  = "teste-public"
gcs_private_bucket_name = "test-private"
gcs_credentials         = "{}"