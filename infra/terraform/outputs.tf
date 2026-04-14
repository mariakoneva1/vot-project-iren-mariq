output "application_namespace" {
  value = kubernetes_namespace.sprintboard.metadata[0].name
}

output "monitoring_namespace" {
  value = kubernetes_namespace.monitoring.metadata[0].name
}

output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}
