terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# -------------------------------------------------------
# StorageClass gp3
# WaitForFirstConsumer: cria o EBS na mesma AZ do pod,
# evitando que o volume fique inacessível após interrupção
# SPOT e reprogramação do pod em outra AZ.
# -------------------------------------------------------

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Retain"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
}

# Remove o default da StorageClass gp2 criada automaticamente pelo EKS,
# evitando conflito de dois defaults simultâneos.
resource "kubernetes_annotations" "gp2_remove_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  depends_on = [kubernetes_storage_class_v1.gp3]
}

# -------------------------------------------------------
# AWS Load Balancer Controller
# -------------------------------------------------------

resource "kubernetes_service_account_v1" "lbc" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = var.lbc_role_arn
    }
  }
}

resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account_v1.lbc.metadata[0].name
  }

  set {
    name  = "nodeSelector.role"
    value = "infra"
  }

  set {
    name  = "tolerations[0].key"
    value = "role"
  }

  set {
    name  = "tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [kubernetes_service_account_v1.lbc]
}

# -------------------------------------------------------
# External Secrets Operator
# -------------------------------------------------------

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  version          = "0.9.19"
  create_namespace = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.eso_irsa_role_arn
  }

  set {
    name  = "nodeSelector.role"
    value = "infra"
  }

  set {
    name  = "tolerations[0].key"
    value = "role"
  }

  set {
    name  = "tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  # webhook e certController são sub-deployments independentes com sua própria spec
  set {
    name  = "webhook.nodeSelector.role"
    value = "infra"
  }

  set {
    name  = "webhook.tolerations[0].key"
    value = "role"
  }

  set {
    name  = "webhook.tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "webhook.tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "certController.nodeSelector.role"
    value = "infra"
  }

  set {
    name  = "certController.tolerations[0].key"
    value = "role"
  }

  set {
    name  = "certController.tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "certController.tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [helm_release.lbc]
  timeout    = 600
}

# -------------------------------------------------------
# Cluster Autoscaler
# -------------------------------------------------------

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.37.0"

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = "us-east-1"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.cluster_autoscaler_role_arn
  }

  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  set {
    name  = "nodeSelector.role"
    value = "infra"
  }

  set {
    name  = "tolerations[0].key"
    value = "role"
  }

  set {
    name  = "tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [helm_release.lbc]
  timeout    = 600
}

# -------------------------------------------------------
# Datadog Agent
# -------------------------------------------------------

resource "kubernetes_namespace_v1" "datadog" {
  metadata {
    name = "datadog"
  }
}

resource "kubernetes_secret_v1" "datadog" {
  metadata {
    name      = "datadog-secret"
    namespace = kubernetes_namespace_v1.datadog.metadata[0].name
  }

  data = {
    api-key = var.datadog_api_key
  }
}

resource "helm_release" "datadog" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = kubernetes_namespace_v1.datadog.metadata[0].name
  version    = "3.113.0"

  set {
    name  = "datadog.apiKeyExistingSecret"
    value = kubernetes_secret_v1.datadog.metadata[0].name
  }

  set {
    name  = "datadog.site"
    value = "datadoghq.com"
  }

  set {
    name  = "datadog.logs.enabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = "true"
  }

  set {
    name  = "datadog.apm.portEnabled"
    value = "true"
  }

  set {
    name  = "datadog.processAgent.enabled"
    value = "true"
  }

  set {
    name  = "datadog.kubeStateMetricsEnabled"
    value = "false"
  }

  set {
    name  = "datadog.kubeStateMetricsCore.enabled"
    value = "true"
  }

  set {
    name  = "datadog.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "clusterAgent.enabled"
    value = "true"
  }

  set {
    name  = "clusterAgent.metricsProvider.enabled"
    value = "true"
  }

  # Evita que o autodiscovery tente monitorar o Redis interno do ArgoCD
  set {
    name  = "datadog.containerExcludeChecks"
    value = "kube_namespace:argocd"
  }

  # Exclui logs do aws-network-policy-agent — emite "failed to get caller" continuamente
  # por race condition no eBPF sob alta densidade de pods; é ruído puro, sem valor diagnóstico
  set {
    name  = "datadog.containerExcludeLogs"
    value = "name:aws-network-policy-agent"
  }

  # DaemonSet agents: tolerate both node groups so metrics are collected from every node
  set {
    name  = "agents.tolerations[0].key"
    value = "role"
  }

  set {
    name  = "agents.tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "agents.tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "agents.tolerations[1].key"
    value = "role"
  }

  set {
    name  = "agents.tolerations[1].value"
    value = "app"
  }

  set {
    name  = "agents.tolerations[1].effect"
    value = "NoSchedule"
  }

  # Cluster Agent: pin to infra nodes
  set {
    name  = "clusterAgent.nodeSelector.role"
    value = "infra"
  }

  set {
    name  = "clusterAgent.tolerations[0].key"
    value = "role"
  }

  set {
    name  = "clusterAgent.tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "clusterAgent.tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [kubernetes_secret_v1.datadog, helm_release.lbc]
  timeout    = 600
}

# -------------------------------------------------------
# Snapshot Controller (CRDs + controller para o EBS CSI)
# -------------------------------------------------------

resource "helm_release" "snapshot_controller" {
  name             = "snapshot-controller"
  repository       = "https://piraeus.io/helm-charts"
  chart            = "snapshot-controller"
  namespace        = "kube-system"
  version          = "3.0.6"

  # Chart v3 usa controller.* e webhook.* — top-level tolerations/nodeSelector são ignorados
  set {
    name  = "controller.nodeSelector.role"
    value = "infra"
  }

  set {
    name  = "controller.tolerations[0].key"
    value = "role"
  }

  set {
    name  = "controller.tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "controller.tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "webhook.nodeSelector.role"
    value = "infra"
  }

  set {
    name  = "webhook.tolerations[0].key"
    value = "role"
  }

  set {
    name  = "webhook.tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "webhook.tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [helm_release.lbc]
  timeout    = 300
}

# -------------------------------------------------------
# Metrics Server
# -------------------------------------------------------

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  set {
    name  = "nodeSelector.role"
    value = "infra"
  }

  set {
    name  = "tolerations[0].key"
    value = "role"
  }

  set {
    name  = "tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [helm_release.lbc]
}

# -------------------------------------------------------
# ArgoCD
# -------------------------------------------------------

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  version          = "7.3.0"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "global.nodeSelector.role"
    value = "infra"
  }

  set {
    name  = "global.tolerations[0].key"
    value = "role"
  }

  set {
    name  = "global.tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "global.tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [helm_release.lbc]
  timeout    = 600
}

# -------------------------------------------------------
# Argo Rollouts
# -------------------------------------------------------

resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  version          = "2.37.7"
  create_namespace = true

  set {
    name  = "dashboard.enabled"
    value = "true"
  }

  set {
    name  = "controller.nodeSelector.role"
    value = "infra"
  }

  set {
    name  = "controller.tolerations[0].key"
    value = "role"
  }

  set {
    name  = "controller.tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "controller.tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "dashboard.nodeSelector.role"
    value = "infra"
  }

  set {
    name  = "dashboard.tolerations[0].key"
    value = "role"
  }

  set {
    name  = "dashboard.tolerations[0].value"
    value = "infra"
  }

  set {
    name  = "dashboard.tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [helm_release.lbc]
  timeout    = 600
}
