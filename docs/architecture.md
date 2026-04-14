# Infrastructure Overview

The production flow uses GitHub Actions for CI, Docker Hub for image distribution, ArgoCD for continuous delivery, Kubernetes for orchestration, and Prometheus/Loki for observability.

Alerting is wired through Alertmanager to a webhook receiver, and all infrastructure is declared through Terraform and Helm.

