output "application_namespace" {
  value = kubernetes_namespace.sprintboard.metadata[0].name
}

output "monitoring_namespace" {
  value = kubernetes_namespace.monitoring.metadata[0].name
}

output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "ingress_namespace" {
  value = kubernetes_namespace.ingress_nginx.metadata[0].name
}

output "application_url" {
  value = "http://${var.app_domain}"
}
