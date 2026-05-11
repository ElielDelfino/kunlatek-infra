VARS := -var-file=env/dev.tfvars

.PHONY: init apply destroy plan import-slr

init:
	terraform init -upgrade

plan:
	terraform plan $(VARS)

apply:
	@echo ">>> Stage 1 — Infra base + IAM"
	terraform apply $(VARS) \
	  -target=aws_iam_service_linked_role.elb \
	  -target=aws_iam_service_linked_role.eks \
	  -target=aws_iam_service_linked_role.eks_nodegroup \
	  -target=aws_iam_service_linked_role.autoscaling \
	  -target=aws_iam_service_linked_role.ec2_spot \
	  -target=aws_iam_service_linked_role.rds \
	  -target=module.network \
	  -target=module.eks_kms \
	  -target=module.eks \
	  -target=module.database \
	  -target=module.ecr \
	  -target=module.irsa_ebs_csi \
	  -target=module.sqs_worker \
	  -target=aws_eks_addon.vpc_cni \
	  -target=aws_eks_addon.ebs_csi \
	  -target=aws_secretsmanager_secret.app \
	  -target=aws_secretsmanager_secret_version.app \
	  -target=aws_iam_role.app_sa \
	  -target=aws_iam_role_policy.app_sa_secrets \
	  -target=aws_iam_role_policy.app_sa_sqs \
	  -target=aws_iam_role.eso \
	  -target=aws_iam_role_policy.eso_secrets
	@echo ">>> Stage 2 — EKS Add-ons (Helm charts)"
	terraform apply $(VARS) -target=module.eks_addons
	@echo ">>> Stage 3 — Apply completo (Datadog + restante)"
	terraform apply $(VARS)
	@echo ">>> Concluido."

destroy:
	terraform destroy $(VARS)

# Importa service-linked roles se ja existirem na conta AWS.
# Execute apenas se o apply falhar com "already exists" nessas roles.
import-slr:
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
