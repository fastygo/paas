# Архитектура с несколькими инстансами Kubero

## Обзор архитектуры

```
┌─────────────────────────────────────────────────────────────┐
│                    Gitea CI/CD (Orchestrator)                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Git Repositories                                      │  │
│  │  - Infrastructure as Code                             │  │
│  │  - Application Code                                    │  │
│  │  - Configuration Management                           │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  CI/CD Pipelines (Gitea Actions / Drone CI)           │  │
│  │  - Build & Test                                        │  │
│  │  - Deploy to Dev                                       │  │
│  │  - Deploy to Production                                │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│  Kubero #1    │ │  Kubero #2    │ │  Kubero #3    │
│  System/Infra │ │  Development  │ │  Production   │
│  VPS          │ │  VPS          │ │  VPS          │
├───────────────┤ ├───────────────┤ ├───────────────┤
│ • K8s Ops     │ │ • Dev Apps    │ │ • Prod Apps   │
│ • Monitoring  │ │ • Test Env    │ │ • Live Apps   │
│ • Logging     │ │ • Staging     │ │ • High Avail  │
│ • Backup      │ │ • Preview     │ │ • Scaling     │
│ • Operators   │ │ • Experiments │ │ • Security    │
└───────────────┘ └───────────────┘ └───────────────┘
```

## Описание компонентов

### 1. Kubero System/Infrastructure (VPS #1)

**Назначение:** Управление инфраструктурой и системными сервисами

**Компоненты:**
- Kubernetes операторы (CNPG, Grafana Operator, etc.)
- Мониторинг (Prometheus, Grafana)
- Логирование (Loki, Vector)
- Backup системы (Velero)
- CI/CD агенты (если нужны)
- Системные утилиты

**Характеристики:**
- Стабильность важнее производительности
- Минимальные изменения
- Высокая доступность для мониторинга

### 2. Kubero Development (VPS #2)

**Назначение:** Разработка и тестирование приложений

**Компоненты:**
- Dev окружения приложений
- Preview/Review Apps (GitOps)
- Тестовые базы данных
- Инструменты разработки
- Демо окружения

**Характеристики:**
- Частые изменения
- Быстрое развертывание
- Можно использовать менее мощное железо
- Можно перезапускать без проблем

### 3. Kubero Production (VPS #3)

**Назначение:** Продакшн окружение

**Компоненты:**
- Production приложения
- Production базы данных
- High Availability конфигурации
- Автомасштабирование
- Мониторинг и алертинг

**Характеристики:**
- Максимальная стабильность
- Высокая производительность
- Минимальные изменения
- Строгий контроль доступа

## Преимущества такой архитектуры

### 1. Изоляция окружений
- Полная изоляция dev и prod
- Невозможно случайно затронуть продакшн из dev
- Разные уровни безопасности

### 2. Независимое масштабирование
- Каждое окружение масштабируется независимо
- Можно использовать разное железо для разных целей
- Оптимизация затрат

### 3. Независимые обновления
- Обновление dev не влияет на prod
- Можно тестировать новые версии Kubero на dev
- Разные версии компонентов

### 4. Безопасность
- Разные уровни доступа
- Prod изолирован от разработки
- Легче соответствовать compliance требованиям

### 5. Производительность
- Нет конкуренции ресурсов между окружениями
- Каждое окружение оптимизировано под свои задачи

## Недостатки и соображения

### 1. Сложность управления
- Три инстанса вместо одного
- Нужна синхронизация конфигураций
- Больше точек отказа

### 2. Затраты
- Три VPS вместо одного
- Больше ресурсов для управления

### 3. Синхронизация
- Нужна синхронизация конфигураций между инстансами
- Версионирование конфигураций

## Архитектура CI/CD с Gitea

### Структура репозиториев

```
repositories/
├── infrastructure/
│   ├── kubero-system/      # Конфигурация для System Kubero
│   ├── kubero-dev/          # Конфигурация для Dev Kubero
│   └── kubero-prod/         # Конфигурация для Prod Kubero
├── applications/
│   ├── app-1/
│   │   ├── .gitea/workflows/
│   │   │   └── deploy.yml   # CI/CD pipeline
│   │   ├── kubernetes/
│   │   │   ├── dev/
│   │   │   └── prod/
│   │   └── src/
│   └── app-2/
└── shared/
    ├── helm-charts/         # Общие Helm charts
    └── kubernetes-base/     # Базовые конфигурации
```

### CI/CD Pipeline Flow

```
┌─────────────────────────────────────────────────────────┐
│  Developer pushes code to Gitea                         │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Gitea CI/CD Triggered                                  │
│  ┌───────────────────────────────────────────────────┐ │
│  │  1. Build & Test                                  │ │
│  │     - Run tests                                    │ │
│  │     - Build Docker image                           │ │
│  │     - Push to registry                             │ │
│  └───────────────────────────────────────────────────┘ │
│                        │                                 │
│                        ▼                                 │
│  ┌───────────────────────────────────────────────────┐ │
│  │  2. Deploy to Dev (Kubero #2)                     │ │
│  │     - Update KuberoApp CRD                        │ │
│  │     - Trigger deployment                          │ │
│  │     - Run smoke tests                             │ │
│  └───────────────────────────────────────────────────┘ │
│                        │                                 │
│                        ▼                                 │
│  ┌───────────────────────────────────────────────────┐ │
│  │  3. Manual Approval (optional)                   │ │
│  │     - Code review                                 │ │
│  │     - QA approval                                 │ │
│  └───────────────────────────────────────────────────┘ │
│                        │                                 │
│                        ▼                                 │
│  ┌───────────────────────────────────────────────────┐ │
│  │  4. Deploy to Prod (Kubero #3)                   │ │
│  │     - Update KuberoApp CRD                        │ │
│  │     - Blue-Green or Rolling deployment            │ │
│  │     - Health checks                                │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Настройка Gitea CI/CD

### Gitea Actions Workflow

Gitea поддерживает Actions (совместимо с GitHub Actions), что позволяет использовать знакомый синтаксис.

### Альтернатива: Drone CI

Drone CI хорошо интегрируется с Gitea и может быть более легковесным решением.

## Конфигурация подключений

### Доступ к Kubernetes кластерам

Каждый Kubero инстанс работает на своем Kubernetes кластере. CI/CD должен иметь доступ ко всем трем кластерам.

### Вариант 1: Kubeconfig с несколькими контекстами

```yaml
# .drone.yml или .gitea/workflows/deploy.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubeconfig
data:
  config: |
    apiVersion: v1
    clusters:
    - cluster:
        server: https://kubero-system.example.com:6443
      name: kubero-system
    - cluster:
        server: https://kubero-dev.example.com:6443
      name: kubero-dev
    - cluster:
        server: https://kubero-prod.example.com:6443
      name: kubero-prod
    contexts:
    - context:
        cluster: kubero-system
        user: system-user
      name: system
    - context:
        cluster: kubero-dev
        user: dev-user
      name: dev
    - context:
        cluster: kubero-prod
        user: prod-user
      name: prod
    current-context: dev
    users:
    - name: system-user
      user:
        token: <system-token>
    - name: dev-user
      user:
        token: <dev-token>
    - name: prod-user
      user:
        token: <prod-token>
```

### Вариант 2: Отдельные секреты для каждого окружения

```yaml
# В Gitea Secrets или Drone Secrets
KUBERNETES_SYSTEM_CONFIG: <base64-encoded-kubeconfig>
KUBERNETES_DEV_CONFIG: <base64-encoded-kubeconfig>
KUBERNETES_PROD_CONFIG: <base64-encoded-kubeconfig>
```

## Синхронизация конфигураций

### GitOps подход

Используйте GitOps инструменты (ArgoCD, Flux) для синхронизации:

```yaml
# ArgoCD Application для каждого Kubero инстанса
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubero-system-config
spec:
  project: default
  source:
    repoURL: https://gitea.example.com/infrastructure/kubero-system.git
    targetRevision: HEAD
    path: configs
  destination:
    server: https://kubernetes.default.svc
    namespace: kubero-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Helmwave подход

Используйте helmwave для управления конфигурациями:

```yaml
# helmwave-system.yml
project: kubero-system
releases:
  - name: system-config
    chart:
      name: ./charts/system
    values:
      - values/system.yaml
    tags: [system]
```

## Примеры конфигураций

### Конфигурация для System Kubero

```yaml
# kubero-system/values.yaml
kubero:
  namespace: kubero-system
  
  # Системные компоненты
  components:
    monitoring:
      enabled: true
      prometheus:
        retention: 30d
      grafana:
        enabled: true
    
    logging:
      enabled: true
      loki:
        retention: 90d
    
    backup:
      enabled: true
      velero:
        schedule: "0 2 * * *"  # Ежедневно в 2:00
    
    operators:
      - name: cnpg
        enabled: true
      - name: grafana-operator
        enabled: true

  # Ресурсы для системных компонентов
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"
```

### Конфигурация для Dev Kubero

```yaml
# kubero-dev/values.yaml
kubero:
  namespace: kubero-dev
  
  # Настройки для разработки
  settings:
    autoDeploy: true  # Автоматическое развертывание при push
    previewApps: true  # Preview apps для PR
    resourceLimits:
      cpu: "500m"
      memory: "512Mi"
  
  # GitOps настройки
  gitops:
    enabled: true
    autoCleanup: true
    cleanupAfter: "7d"  # Удалять preview apps через 7 дней
  
  # Ресурсы
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"
```

### Конфигурация для Prod Kubero

```yaml
# kubero-prod/values.yaml
kubero:
  namespace: kubero-prod
  
  # Настройки для продакшена
  settings:
    autoDeploy: false  # Только через approval
    requireApproval: true
    healthChecks: true
    rollbackOnFailure: true
  
  # High Availability
  ha:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
  
  # Мониторинг и алертинг
  monitoring:
    enabled: true
    alerts:
      enabled: true
  
  # Ресурсы
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "4Gi"
      cpu: "2000m"
```

## Безопасность

### Разделение доступа

```yaml
# RBAC для разных окружений
---
# Dev - более открытый доступ
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: dev-developer
  namespace: kubero-dev
rules:
- apiGroups: ["kubero.dev"]
  resources: ["kuberoapps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

---
# Prod - ограниченный доступ
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: prod-developer
  namespace: kubero-prod
rules:
- apiGroups: ["kubero.dev"]
  resources: ["kuberoapps"]
  verbs: ["get", "list", "watch"]  # Только чтение
  # Создание/обновление только через CI/CD
```

### Network Policies

```yaml
# Изоляция между окружениями
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prod-isolation
  namespace: kubero-prod
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Разрешить только из CI/CD системы
  - from:
    - namespaceSelector:
        matchLabels:
          name: ci-cd
  egress:
  # Разрешить только необходимые соединения
  - to:
    - namespaceSelector:
        matchLabels:
          name: kubero-system  # Для мониторинга
```

## Мониторинг и наблюдение

### Централизованный мониторинг

System Kubero может собирать метрики со всех трех инстансов:

```yaml
# Prometheus scrape config для всех Kubero инстансов
scrape_configs:
  - job_name: 'kubero-system'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - kubero-system
  
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

## Резервное копирование

### Velero для всех окружений

```yaml
# Velero backup schedule
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup-dev
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
    - kubero-dev
    storageLocation: default
    ttl: 720h0m0s
---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup-prod
spec:
  schedule: "0 3 * * *"
  template:
    includedNamespaces:
    - kubero-prod
    storageLocation: default
    ttl: 2160h0m0s  # 90 дней для prod
```

## Рекомендации по развертыванию

### Порядок установки

1. **System Kubero** - сначала инфраструктура
2. **Dev Kubero** - затем dev окружение
3. **Prod Kubero** - в последнюю очередь

### Минимальные требования

**System VPS:**
- 4 CPU, 8GB RAM, 100GB диск
- Стабильное соединение

**Dev VPS:**
- 4 CPU, 8GB RAM, 80GB диск
- Можно меньше ресурсов

**Prod VPS:**
- 8 CPU, 16GB RAM, 200GB диск
- Высокая производительность
- Резервное копирование

## Заключение

Архитектура с тремя инстансами Kubero обеспечивает:

✅ **Полную изоляцию** окружений
✅ **Независимое масштабирование** каждого окружения
✅ **Безопасность** через разделение доступа
✅ **Гибкость** в управлении ресурсами
✅ **Соответствие** best practices для production

Основные вызовы:
- Синхронизация конфигураций (решается через GitOps)
- Управление доступом (решается через RBAC и Network Policies)
- Мониторинг всех инстансов (решается через централизованный мониторинг)

