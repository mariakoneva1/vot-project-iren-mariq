# Architecture Overview

SprintBoard is delivered as a GitOps-based platform demo around a small Python web application.

## Main Flow

1. A developer pushes code to GitHub.
2. GitHub Actions runs `pre-commit`, unit tests, Helm linting, and Terraform validation.
3. On `main`, CI builds and pushes a Docker image to Docker Hub.
4. The CD workflow updates the production Helm values file with the new image tag.
5. ArgoCD detects the Git change and syncs the release into Kubernetes.
6. Prometheus scrapes metrics, Loki collects logs, Grafana visualizes the data, and Alertmanager sends webhook alerts.

## Runtime Topology

### Application Layer

- `SprintBoard` runs as a Kubernetes `Deployment`
- traffic reaches the app through `ingress-nginx` and a `Service`
- SQLite data is stored on a `PersistentVolumeClaim`
- `/healthz` is used for probes
- `/metrics` is used for Prometheus scraping

### GitOps Layer

- ArgoCD watches the Git repository
- the ArgoCD `AppProject` restricts the source repository and destination namespace
- the ArgoCD `Application` deploys the Helm chart from `deploy/helm/sprintboard`

### Observability Layer

- Prometheus scrapes application metrics through `ServiceMonitor`
- Prometheus evaluates rules from `PrometheusRule`
- Alertmanager sends webhook notifications
- Promtail ships container logs to Loki
- Grafana dashboards visualize SprintBoard metrics

## Namespaces

- `sprintboard`: application workloads
- `argocd`: GitOps controllers
- `monitoring`: Prometheus, Alertmanager, Grafana, Loki, Promtail
- `ingress-nginx`: ingress controller

## Infrastructure Sources

- `infra/kind/kind-config.yaml`: local cluster definition
- `infra/terraform/`: cluster add-ons, secrets, monitoring stack, and ArgoCD resources
- `deploy/helm/sprintboard/`: application packaging
- `deploy/argocd/`: standalone GitOps manifests

## Secrets and Configuration

- CI/CD credentials live in GitHub Secrets
- runtime secrets are created as Kubernetes Secrets by Terraform
- non-secret application settings are injected through a ConfigMap
- `detect-secrets` and pre-commit hooks reduce accidental secret leakage
