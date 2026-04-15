#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-sprintboard}"
APP_DOMAIN="${APP_DOMAIN:-sprintboard.127.0.0.1.nip.io}"
INGRESS_CLASS_NAME="${INGRESS_CLASS_NAME:-nginx}"
GITOPS_TARGET_REVISION="${GITOPS_TARGET_REVISION:-main}"

usage() {
    cat <<EOF
Usage: $(basename "$0") \\
  --gitops-repo-url <url> \\
  --dockerhub-username <user> \\
  --dockerhub-token <token> \\
  --notification-webhook-url <url> \\
  --grafana-admin-password <password>

Optional environment variables:
  CLUSTER_NAME              (default: sprintboard)
  APP_DOMAIN                (default: sprintboard.127.0.0.1.nip.io)
  INGRESS_CLASS_NAME        (default: nginx)
  GITOPS_TARGET_REVISION    (default: main)
EOF
    exit 1
}

GITOPS_REPO_URL=""
DOCKERHUB_USERNAME=""
DOCKERHUB_TOKEN=""
NOTIFICATION_WEBHOOK_URL=""
GRAFANA_ADMIN_PASSWORD=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --gitops-repo-url) GITOPS_REPO_URL="$2"; shift 2 ;;
        --dockerhub-username) DOCKERHUB_USERNAME="$2"; shift 2 ;;
        --dockerhub-token) DOCKERHUB_TOKEN="$2"; shift 2 ;;
        --notification-webhook-url) NOTIFICATION_WEBHOOK_URL="$2"; shift 2 ;;
        --grafana-admin-password) GRAFANA_ADMIN_PASSWORD="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

for var in GITOPS_REPO_URL DOCKERHUB_USERNAME DOCKERHUB_TOKEN NOTIFICATION_WEBHOOK_URL GRAFANA_ADMIN_PASSWORD; do
    if [[ -z "${!var}" ]]; then
        echo "Error: --$(echo "$var" | tr '[:upper:]' '[:lower:]' | tr '_' '-') is required."
        usage
    fi
done

require_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo "Error: required tool '$1' not found in PATH." >&2
        exit 1
    fi
}

require_tool kind
require_tool kubectl
require_tool terraform

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIND_CONFIG="${REPO_ROOT}/infra/kind/kind-config.yaml"
TERRAFORM_DIR="${REPO_ROOT}/infra/terraform"
KUBECONFIG_PATH="${HOME}/.kube/config"
KUBE_CONTEXT="kind-${CLUSTER_NAME}"

if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
    echo "Creating kind cluster '${CLUSTER_NAME}'..."
    kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}"
fi

kubectl config use-context "${KUBE_CONTEXT}" >/dev/null
kubectl wait --for=condition=Ready nodes --all --timeout=180s

pushd "${TERRAFORM_DIR}" >/dev/null
terraform init
terraform apply -auto-approve \
    -var="kubeconfig_path=${KUBECONFIG_PATH}" \
    -var="kubeconfig_context=${KUBE_CONTEXT}" \
    -var="gitops_repo_url=${GITOPS_REPO_URL}" \
    -var="gitops_target_revision=${GITOPS_TARGET_REVISION}" \
    -var="dockerhub_username=${DOCKERHUB_USERNAME}" \
    -var="dockerhub_token=${DOCKERHUB_TOKEN}" \
    -var="notification_webhook_url=${NOTIFICATION_WEBHOOK_URL}" \
    -var="grafana_admin_password=${GRAFANA_ADMIN_PASSWORD}" \
    -var="app_domain=${APP_DOMAIN}" \
    -var="ingress_class_name=${INGRESS_CLASS_NAME}"
popd >/dev/null

echo ""
echo "Cluster bootstrap completed."
echo "Application: http://${APP_DOMAIN}"
echo "Grafana: kubectl -n monitoring get svc, then port-forward the Grafana service to localhost:3000"
echo "ArgoCD: kubectl -n argocd get svc, then port-forward the ArgoCD server service to localhost:8080"
