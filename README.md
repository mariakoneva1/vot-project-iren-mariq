# SprintBoard

SprintBoard е леко web базирано приложение за управление на задачи в три колони: `TODO`, `DOING` и `DONE`. Проектът е създаден така, че да покрива цял DevOps lifecycle: локално стартиране, Docker build, CI pipeline, Docker Hub публикация, GitOps CD към Kubernetes, observability, alerting, secrets management и Infrastructure as Code.

## Какъв проблем решава

Проектът демонстрира как едно малко, но реално приложение може да бъде доставяно по професионален начин:

- кодът минава през `pre-commit` проверки преди commit
- CI валидира качеството и тестовете
- Docker image се build-ва и push-ва автоматично
- CD променя production манифестите и ArgoCD синхронизира клъстера
- метрики, логове и аларми дават оперативна видимост

## Архитектурна диаграма

![Infrastructure Diagram](docs/infrastructure-diagram.svg)

Допълнително описание има в `docs/architecture.md`.

## Локално стартиране

### 1. Стартиране с Python

Изискване: `Python 3.12+`

```bash
python -m unittest discover -s tests -v
python -m app.server
```

Приложението ще бъде достъпно на `http://localhost:8000`.

Полезни endpoint-и:

- `GET /`
- `GET /healthz`
- `GET /metrics`

### 2. Стартиране с Docker

```bash
docker build -t sprintboard:local .
docker run -p 8000:8000 -v $(pwd)/data:/data sprintboard:local
```

### 3. Стартиране с Docker Compose

```bash
docker compose up --build
```

## Git repository

Локалното repository е инициализирано с `git init`. Препоръчителна последователност за свързване към GitHub:

```bash
git remote add origin https://github.com/<user>/<repo>.git
git add .
git commit -m "Initial DevOps delivery"
git push -u origin main
```

## Pre-commit hooks

Файлът `.pre-commit-config.yaml` включва:

- проверки за YAML, whitespace и merge conflicts
- засичане на private keys
- `detect-secrets` с baseline файл `.secrets.baseline`
- `ruff` lint + format
- unit tests преди commit

Инсталация:

```bash
pip install -r requirements-dev.txt
pre-commit install
pre-commit run --all-files
```

## CI Pipeline

Workflow: `.github/workflows/ci.yml`

CI pipeline-ът:

1. checkout-ва кода
2. инсталира dev tooling
3. пуска `pre-commit` hooks
4. изпълнява unit tests
5. build-ва и push-ва Docker image към Docker Hub
6. изпраща webhook notification за резултата

Нужни GitHub Secrets:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `WEBHOOK_URL`

## CD Pipeline

Избрана технология: `ArgoCD` + `Helm` + `GitHub Actions`

Workflow: `.github/workflows/cd.yml`

CD потокът е:

1. успешен `CI` workflow върху `main`
2. update на `deploy/helm/sprintboard/values-prod.yaml` с новия Docker tag
3. commit обратно в repository-то
4. ArgoCD засича промяната и синхронизира Kubernetes deployment-а
5. изпраща се webhook notification

Файлът `deploy/argocd/application.yaml` съдържа standalone ArgoCD Application manifest, а Terraform създава същия ресурс автоматизирано.

## Kubernetes оркестрация

Избран оркестратор: `Kubernetes`

Helm chart: `deploy/helm/sprintboard`

Той създава:

- `Deployment`
- `Service`
- `Ingress`
- `PersistentVolumeClaim`
- `ConfigMap`
- `ServiceMonitor`
- `PrometheusRule`

## Observability и Alerting

Налични са минимум задължителните operational capabilities:

- метрики през `GET /metrics`
- структурирани JSON логове към stdout
- `ServiceMonitor` за Prometheus
- `PrometheusRule` за application errors и unavailable replicas
- `AlertmanagerConfig` с webhook receiver
- `Loki + Promtail` за събиране на логове

## Infrastructure as Code

Папка: `infra/terraform`

Terraform управлява:

- namespaces: `argocd`, `monitoring`, `sprintboard`
- Docker Hub registry secret
- Grafana admin secret
- Alertmanager webhook secret
- `argo-cd` Helm release
- `kube-prometheus-stack` Helm release
- `loki` и `promtail` Helm releases
- ArgoCD `Application` ресурс

Примерен конфигурационен файл:

```bash
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
```

После:

```bash
cd infra/terraform
terraform init
terraform plan
terraform apply
```

## Configuration и Secrets Management

Secrets не се държат в кода.

Използван подход:

- GitHub Secrets за CI/CD credentials и webhook URL
- Kubernetes Secrets, създадени от Terraform
- `ConfigMap` за несекретна runtime конфигурация
- опционален `secretRefs.existingSecretName` в Helm chart за допълнителни application secrets

## Използвани технологии и версии

- Python `3.12+`
- SQLite `3`
- Docker `26+`
- Docker Compose `v2`
- GitHub Actions
- Helm `3.15+`
- Kubernetes `1.29+`
- ArgoCD `2.x`
- Terraform `1.8+`
- Prometheus / Alertmanager
- Loki / Promtail
- Ruff `0.11.7`
- pre-commit `4.2.0`
- detect-secrets `1.5.0`

## Структура на проекта

```text
.
├── app/                     # Web приложението, статични файлове и WSGI server
├── tests/                   # Unit тестове
├── scripts/                 # Помощни automation скриптове
├── .github/workflows/       # CI и CD pipelines
├── deploy/argocd/           # Standalone ArgoCD application manifest
├── deploy/helm/sprintboard/ # Helm chart за приложението
├── docs/                    # Архитектурна документация и диаграма
├── infra/terraform/         # IaC за Kubernetes, monitoring и GitOps
├── Dockerfile               # Container build
├── docker-compose.yml       # Локално стартиране с Docker Compose
└── README.md                # Основна документация
```

## Бърза проверка

```bash
python -m unittest discover -s tests -v
```
