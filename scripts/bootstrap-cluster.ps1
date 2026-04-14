param(
    [string]$ClusterName = "sprintboard",
    [Parameter(Mandatory = $true)]
    [string]$GitOpsRepoUrl,
    [Parameter(Mandatory = $true)]
    [string]$DockerHubUsername,
    [Parameter(Mandatory = $true)]
    [string]$DockerHubToken,
    [Parameter(Mandatory = $true)]
    [string]$NotificationWebhookUrl,
    [Parameter(Mandatory = $true)]
    [string]$GrafanaAdminPassword,
    [string]$AppDomain = "sprintboard.127.0.0.1.nip.io",
    [string]$IngressClassName = "nginx",
    [string]$TerraformDirectory = "infra/terraform",
    [string]$KindConfigPath = "infra/kind/kind-config.yaml",
    [string]$GitOpsTargetRevision = "main"
)

$ErrorActionPreference = "Stop"

function Require-Tool {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required tool '$Name' was not found in PATH."
    }
}

Require-Tool kind
Require-Tool kubectl
Require-Tool terraform

$repoRoot = Split-Path -Parent $PSScriptRoot
$kindConfig = Join-Path $repoRoot $KindConfigPath
$terraformDir = Join-Path $repoRoot $TerraformDirectory
$kubeconfigPath = Join-Path $env:USERPROFILE ".kube\config"
$kubeContext = "kind-$ClusterName"

$existingClusters = kind get clusters
if ($existingClusters -notcontains $ClusterName) {
    kind create cluster --name $ClusterName --config $kindConfig
}

kubectl config use-context $kubeContext | Out-Null
kubectl wait --for=condition=Ready nodes --all --timeout=180s

Push-Location $terraformDir
try {
    terraform init
    terraform apply -auto-approve `
        "-var=kubeconfig_path=$kubeconfigPath" `
        "-var=kubeconfig_context=$kubeContext" `
        "-var=gitops_repo_url=$GitOpsRepoUrl" `
        "-var=gitops_target_revision=$GitOpsTargetRevision" `
        "-var=dockerhub_username=$DockerHubUsername" `
        "-var=dockerhub_token=$DockerHubToken" `
        "-var=notification_webhook_url=$NotificationWebhookUrl" `
        "-var=grafana_admin_password=$GrafanaAdminPassword" `
        "-var=app_domain=$AppDomain" `
        "-var=ingress_class_name=$IngressClassName"
}
finally {
    Pop-Location
}

Write-Host "Cluster bootstrap completed." -ForegroundColor Green
Write-Host "Application: http://$AppDomain"
Write-Host "Grafana: list services with 'kubectl -n monitoring get svc' and port-forward the Grafana service to localhost:3000"
Write-Host "ArgoCD: list services with 'kubectl -n argocd get svc' and port-forward the ArgoCD server service to localhost:8080"
