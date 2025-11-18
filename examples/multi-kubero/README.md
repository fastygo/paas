# Примеры конфигураций для Multi-Kubero архитектуры

Этот каталог содержит примеры конфигураций для архитектуры с тремя инстансами Kubero.

## Структура

```
examples/multi-kubero/
├── README.md                          # Этот файл
├── gitea-workflow-example.yml         # Пример Gitea Actions workflow
├── drone-ci-example.yml               # Пример Drone CI pipeline
└── kubero-configs/
    ├── kubero-system-values.yaml      # Конфигурация System Kubero
    ├── kubero-dev-values.yaml         # Конфигурация Dev Kubero
    └── kubero-prod-values.yaml       # Конфигурация Prod Kubero
```

## Использование

### 1. Настройка Gitea CI/CD

#### Вариант A: Gitea Actions

Используйте файл `gitea-workflow-example.yml` как шаблон:

```bash
# В репозитории приложения создайте:
mkdir -p .gitea/workflows
cp gitea-workflow-example.yml .gitea/workflows/deploy.yml
```

Настройте секреты в Gitea:
- `REGISTRY_USERNAME` - имя пользователя для registry
- `REGISTRY_PASSWORD` - пароль для registry
- `KUBERNETES_DEV_CONFIG` - base64 encoded kubeconfig для dev
- `KUBERNETES_PROD_CONFIG` - base64 encoded kubeconfig для prod

#### Вариант B: Drone CI

Используйте файл `drone-ci-example.yml`:

```bash
# В корне репозитория:
cp drone-ci-example.yml .drone.yml
```

Настройте секреты в Drone:
- `registry_username`
- `registry_password`
- `kubernetes_dev_config`
- `kubernetes_prod_config`
- `slack_webhook` (опционально)

### 2. Установка Kubero инстансов

#### System Kubero

```bash
helm install kubero-system ./kubero-chart \
  -f kubero-configs/kubero-system-values.yaml \
  -n kubero-system \
  --create-namespace
```

#### Dev Kubero

```bash
helm install kubero-dev ./kubero-chart \
  -f kubero-configs/kubero-dev-values.yaml \
  -n kubero-dev \
  --create-namespace
```

#### Prod Kubero

```bash
helm install kubero-prod ./kubero-chart \
  -f kubero-configs/kubero-prod-values.yaml \
  -n kubero-prod \
  --create-namespace
```

### 3. Настройка доступа

#### Создание ServiceAccount для CI/CD

```yaml
# Для Dev окружения
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-cd-dev
  namespace: kubero-dev
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ci-cd-dev-role
  namespace: kubero-dev
rules:
- apiGroups: ["kubero.dev"]
  resources: ["kuberoapps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-cd-dev-binding
  namespace: kubero-dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ci-cd-dev-role
subjects:
- kind: ServiceAccount
  name: ci-cd-dev
  namespace: kubero-dev
```

#### Создание токена для доступа

```bash
# Создать секрет с токеном
kubectl create secret generic ci-cd-dev-token \
  --from-literal=token=$(kubectl create token ci-cd-dev -n kubero-dev) \
  -n kubero-dev
```

### 4. Настройка мониторинга

System Kubero должен собирать метрики со всех инстансов:

```yaml
# В Prometheus конфигурации System Kubero
scrape_configs:
  - job_name: 'kubero-dev'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - kubero-dev
  
  - job_name: 'kubero-prod'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - kubero-prod
```

## Проверка работы

### Проверка подключения к кластерам

```bash
# Dev
kubectl --context=dev get nodes
kubectl --context=dev get kuberoapps

# Prod
kubectl --context=prod get nodes
kubectl --context=prod get kuberoapps
```

### Тестовый деплой

```bash
# Создать тестовое приложение в Dev
kubectl --context=dev apply -f - <<EOF
apiVersion: kubero.dev/v1alpha1
kind: KuberoApp
metadata:
  name: test-app
  namespace: default
spec:
  name: test-app
  pipeline: dev-pipeline
  phase: development
  image: nginx:latest
  replicas: 1
EOF
```

## Дополнительные ресурсы

- [Gitea Actions Documentation](https://docs.gitea.com/usage/actions/overview)
- [Drone CI Documentation](https://docs.drone.io/)
- [Kubero Documentation](https://kubero.dev/docs)

