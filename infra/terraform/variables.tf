variable "kubeconfig_path" {
  description = "Absolute path to the kubeconfig file used for Terraform operations."
  type        = string
}

variable "kubeconfig_context" {
  description = "Kubernetes context name used by Terraform."
  type        = string
}

variable "gitops_repo_url" {
  description = "Git repository URL monitored by ArgoCD."
  type        = string
}

variable "gitops_target_revision" {
  description = "Git revision used by ArgoCD."
  type        = string
  default     = "main"
}

variable "dockerhub_username" {
  description = "Docker Hub username used for the registry pull secret."
  type        = string
}

variable "dockerhub_token" {
  description = "Docker Hub access token used for the registry pull secret."
  type        = string
  sensitive   = true
}

variable "notification_webhook_url" {
  description = "Webhook endpoint used by Alertmanager notifications."
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password injected through Terraform."
  type        = string
  sensitive   = true
}

variable "app_domain" {
  description = "Public DNS name for the production ingress."
  type        = string
  default     = "sprintboard.example.com"
}
