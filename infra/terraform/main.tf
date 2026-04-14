provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_namespace" "sprintboard" {
  metadata {
    name = "sprintboard"
  }
}

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "kubernetes_secret" "dockerhub_registry" {
  metadata {
    name      = "dockerhub-registry"
    namespace = kubernetes_namespace.sprintboard.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "https://index.docker.io/v1/" = {
          username = var.dockerhub_username
          password = var.dockerhub_token
          auth     = base64encode("${var.dockerhub_username}:${var.dockerhub_token}")
        }
      }
    })
  }
}

resource "kubernetes_secret" "alertmanager_webhook" {
  metadata {
    name      = "alertmanager-webhook"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    url = var.notification_webhook_url
  }
}

resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    admin-user     = "admin"
    admin-password = var.grafana_admin_password
  }
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = kubernetes_namespace.ingress_nginx.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      controller = {
        hostPort = {
          enabled = true
        }
        service = {
          type = "NodePort"
        }
        nodeSelector = {
          "ingress-ready" = "true"
        }
        tolerations = [
          {
            key      = "node-role.kubernetes.io/control-plane"
            operator = "Exists"
            effect   = "NoSchedule"
          }
        ]
      }
    })
  ]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = "true"
        }
      }
    })
  ]

  depends_on = [helm_release.ingress_nginx]
}

resource "kubernetes_manifest" "argocd_project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "sprintboard"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      description = "SprintBoard GitOps project"
      sourceRepos = [var.gitops_repo_url]
      destinations = [
        {
          namespace = kubernetes_namespace.sprintboard.metadata[0].name
          server    = "https://kubernetes.default.svc"
        }
      ]
      clusterResourceWhitelist = [
        {
          group = "*"
          kind  = "*"
        }
      ]
      namespaceResourceWhitelist = [
        {
          group = "*"
          kind  = "*"
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      grafana = {
        admin = {
          existingSecret = kubernetes_secret.grafana_admin.metadata[0].name
          userKey        = "admin-user"
          passwordKey    = "admin-password" # pragma: allowlist secret
        }
        sidecar = {
          dashboards = {
            enabled         = true
            label           = "grafana_dashboard"
            labelValue      = "1"
            searchNamespace = "ALL"
          }
        }
        additionalDataSources = [
          {
            name      = "Loki"
            type      = "loki"
            access    = "proxy"
            url       = "http://loki-gateway.monitoring.svc.cluster.local"
            isDefault = false
          }
        ]
      }
      alertmanager = {
        alertmanagerSpec = {
          alertmanagerConfigSelector = {
            matchLabels = {
              alertmanagerConfig = "sprintboard"
            }
          }
        }
      }
      prometheus = {
        prometheusSpec = {
          serviceMonitorNamespaceSelector = {}
          ruleNamespaceSelector           = {}
        }
      }
    })
  ]

  depends_on = [helm_release.ingress_nginx]
}

resource "kubernetes_config_map" "grafana_dashboard" {
  metadata {
    name      = "sprintboard-grafana-dashboard"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "sprintboard-overview.json" = file("${path.module}/../grafana/dashboards/sprintboard-overview.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false
}

resource "helm_release" "promtail" {
  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      config = {
        clients = [
          {
            url = "http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push"
          }
        ]
      }
    })
  ]

  depends_on = [helm_release.loki]
}

resource "kubernetes_manifest" "alertmanager_config" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1alpha1"
    kind       = "AlertmanagerConfig"
    metadata = {
      name      = "sprintboard-webhook"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        alertmanagerConfig = "sprintboard"
      }
    }
    spec = {
      route = {
        receiver = "webhook"
        groupBy  = ["alertname", "severity"]
      }
      receivers = [
        {
          name = "webhook"
          webhookConfigs = [
            {
              sendResolved = true
              urlSecret = {
                name = kubernetes_secret.alertmanager_webhook.metadata[0].name
                key  = "url"
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_manifest" "argocd_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "sprintboard"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      project = "sprintboard"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_target_revision
        path           = "deploy/helm/sprintboard"
        helm = {
          valueFiles = ["values.yaml", "values-prod.yaml"]
          parameters = [
            {
              name  = "ingress.className"
              value = var.ingress_class_name
            },
            {
              name  = "ingress.host"
              value = var.app_domain
            },
            {
              name  = "config.baseUrl"
              value = "http://${var.app_domain}"
            }
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.sprintboard.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [kubernetes_manifest.argocd_project]
}
