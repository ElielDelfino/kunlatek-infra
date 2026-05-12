VARS := -var-file=env/dev.tfvars

.PHONY: init apply destroy plan

init:
	terraform init -upgrade

plan:
	terraform plan $(VARS)

apply:
	@echo ">>> Stage 1 — Infra base + IAM"
	terraform apply $(VARS) \
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
