output "lbc_release_name" {
  value       = helm_release.lbc.name
  description = "Nome do Helm release do AWS Load Balancer Controller"
}

output "datadog_namespace" {
  value       = kubernetes_namespace_v1.datadog.metadata[0].name
  description = "Namespace onde o Datadog Agent está instalado"
}

output "argocd_namespace" {
  value       = helm_release.argocd.namespace
  description = "Namespace onde o ArgoCD está instalado"
}
