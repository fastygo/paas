# Архитектура целевой системы сборки приложений

## Обзор системы

Ваша целевая система включает:

1. **IAM + SSO** - аутентификация и единый вход
2. **Gitea** - Git сервер для пользователей и их приложений
3. **CodeSandbox** - среда разработки для пользователей
4. **Kubero** - платформа для развертывания приложений
5. **PostgreSQL** - несколько раздельных баз данных
6. **User Applications** - контейнеры для приложений пользователей

## Архитектурная диаграмма

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Layer                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │   Developers │  │   Users      │  │   Admins     │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Authentication Layer                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  IAM (Casdoor) + SSO (OAuth2/OIDC)                       │  │
│  │  - User Management                                        │  │
│  │  - Authentication                                         │  │
│  │  - Authorization                                          │  │
│  │  - Single Sign-On для всех сервисов                       │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Gitea      │  │ CodeSandbox  │  │   Kubero     │
│              │  │              │  │              │
│  - Git Repos │  │ - Dev Env    │  │ - App Deploy │
│  - CI/CD     │  │ - Containers │  │ - Pipelines  │
│  - Webhooks  │  │ - Sandbox    │  │ - Management │
└──────────────┘  └──────────────┘  └──────────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Application Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │ User App #1  │  │ User App #2  │  │ User App #N  │        │
│  │ Container    │  │ Container    │  │ Container    │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Data Layer                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │ PostgreSQL   │  │ PostgreSQL   │  │ PostgreSQL   │        │
│  │  (Gitea DB)  │  │ (App DB #1)  │  │ (App DB #2)  │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

## Компоненты системы

### 1. IAM + SSO (Casdoor)

**Назначение:**
- Управление пользователями
- Аутентификация для всех сервисов
- Единый вход (SSO) через OAuth2/OIDC

**Развертывание:**
- Через Kubero или отдельный Deployment
- Использует PostgreSQL для хранения данных

**Интеграция:**
- Gitea - OAuth2 провайдер
- CodeSandbox - OAuth2 провайдер
- Kubero UI - OAuth2 провайдер

### 2. Gitea

**Назначение:**
- Git репозитории для пользователей
- Хранение кода приложений
- CI/CD через webhooks
- Интеграция с Kubero для автоматического деплоя

**Развертывание:**
- Через Kubero или Helm chart
- Использует отдельный PostgreSQL

**Особенности:**
- Интеграция с IAM через OAuth2
- Webhooks для автоматического деплоя
- Возможность создания организаций и команд

### 3. CodeSandbox

**Назначение:**
- Интерактивная среда разработки для пользователей
- Запуск контейнеров для экспериментов
- Интеграция с Git репозиториями

**Развертывание:**
- Отдельные контейнеры для каждого пользователя
- Управление через Kubero или отдельный сервис

**Особенности:**
- Изоляция между пользователями
- Ограничение ресурсов на пользователя
- Интеграция с IAM

### 4. Kubero

**Назначение:**
- Управление развертыванием приложений
- CI/CD pipelines
- Управление ресурсами

**Развертывание:**
- Основной компонент системы
- Управляет всеми приложениями пользователей

**Особенности:**
- Интеграция с Gitea через webhooks
- Автоматический деплой при push
- Управление несколькими PostgreSQL инстансами

### 5. PostgreSQL (несколько инстансов)

**Назначение:**
- **PostgreSQL #1** - база данных для Gitea
- **PostgreSQL #2-N** - базы данных для приложений пользователей

**Развертывание:**
- Через CloudNativePG оператор
- Отдельный кластер для каждого приложения (опционально)
- Или shared PostgreSQL с отдельными базами

## Поэтапный план развертывания

### Этап 1: Локальное изучение (2-3 недели)

#### Неделя 1: Kubernetes основы
- Установка Kind локально
- Изучение Pods, Deployments, Services
- Развертывание простых приложений

#### Неделя 2: Kubero
- Установка Kubero локально
- Создание первого приложения
- Понимание Pipelines

#### Неделя 3: Gitea + IAM
- Установка Gitea локально (Docker Compose)
- Установка Casdoor (IAM) через Kubero
- Настройка интеграции

### Этап 2: Прототип в облаке (2-3 недели)

#### Неделя 1: Базовая инфраструктура
- Создание managed Kubernetes кластера
- Установка Kubero
- Установка CloudNativePG оператора

#### Неделя 2: Основные компоненты
- Развертывание IAM (Casdoor)
- Развертывание Gitea
- Настройка SSO между компонентами

#### Неделя 3: Интеграция
- Настройка webhook Gitea → Kubero
- Создание первого приложения пользователя
- Настройка автоматического деплоя

### Этап 3: CodeSandbox и масштабирование (2-4 недели)

#### Неделя 1-2: CodeSandbox
- Развертывание CodeSandbox
- Интеграция с IAM
- Настройка изоляции контейнеров

#### Неделя 3-4: Масштабирование
- Настройка автомасштабирования
- Разделение PostgreSQL инстансов
- Мониторинг и алертинг

## Конфигурация компонентов

### IAM (Casdoor) через Kubero

```yaml
apiVersion: kubero.dev/v1alpha1
kind: KuberoApp
metadata:
  name: casdoor-iam
spec:
  name: casdoor-iam
  pipeline: system-pipeline
  phase: production
  git:
    url: https://github.com/casbin/casdoor
    branch: master
  buildpack: dockerfile
  image: casbin/casdoor:latest
  replicas: 2
  env:
    - name: RUNNING_IN_DOCKER
      value: "true"
    - name: driverName
      value: "postgres"
    - name: dataSourceName
      valueFrom:
        secretKeyRef:
          name: casdoor-db-secret
          key: connection-string
  addons:
    - name: casdoor-postgres
      type: postgresql
```

### Gitea через Kubero

```yaml
apiVersion: kubero.dev/v1alpha1
kind: KuberoApp
metadata:
  name: gitea
spec:
  name: gitea
  pipeline: system-pipeline
  phase: production
  git:
    url: https://github.com/go-gitea/gitea
    branch: main
  buildpack: dockerfile
  image: gitea/gitea:latest
  replicas: 2
  env:
    - name: GITEA__database__DB_TYPE
      value: "postgres"
    - name: GITEA__database__HOST
      value: "gitea-postgres-rw"
    - name: GITEA__server__DOMAIN
      value: "gitea.example.com"
  addons:
    - name: gitea-postgres
      type: postgresql
```

### PostgreSQL через CloudNativePG

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: gitea-postgres
spec:
  instances: 2
  bootstrap:
    initdb:
      database: gitea
      owner: gitea
      secret:
        name: gitea-db-secret
  storage:
    size: 50Gi
    storageClass: standard
```

## Интеграция компонентов

### SSO Flow

```
User → IAM (Casdoor) → Authenticate
                    ↓
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
    Gitea      CodeSandbox   Kubero UI
    (OAuth2)    (OAuth2)      (OAuth2)
```

### CI/CD Flow

```
Developer → Gitea (Push Code)
                ↓
        Gitea Webhook
                ↓
        Kubero Pipeline
                ↓
        Build & Deploy
                ↓
        User Application Container
```

## Рекомендации по ресурсам

### Для начала (локально)

- **CPU:** 4 cores
- **RAM:** 8GB
- **Disk:** 100GB

### Для прототипа в облаке

- **Kubernetes кластер:** $12-20/месяц (DigitalOcean)
- **Дополнительные узлы:** по мере необходимости
- **Storage:** $0.10/GB/месяц

### Для production

- **System компоненты:** 4 CPU, 8GB RAM
- **User applications:** автомасштабирование от 2 до 10 узлов
- **PostgreSQL:** отдельные инстансы для каждого приложения

## Безопасность

### Изоляция пользователей

- Каждое приложение пользователя в отдельном namespace
- Network Policies для изоляции трафика
- Resource Quotas для ограничения ресурсов

### Доступ к базам данных

- Отдельные PostgreSQL кластеры для каждого приложения
- Или отдельные базы данных в shared кластере
- Credentials через Kubernetes Secrets

## Мониторинг

### Централизованный мониторинг

- Prometheus для сбора метрик
- Grafana для визуализации
- Loki для логов
- Алерты через Alertmanager

### Мониторинг компонентов

- IAM - метрики аутентификации
- Gitea - метрики Git операций
- CodeSandbox - использование ресурсов
- User Applications - метрики приложений
- PostgreSQL - метрики баз данных

## Следующие шаги

1. **Сегодня:** Установите Kind локально и создайте первый кластер
2. **Эта неделя:** Изучите основы Kubernetes
3. **Следующая неделя:** Установите Kubero локально
4. **Через 2 недели:** Переходите в облако
5. **Через месяц:** Разверните все компоненты в production

## Полезные ресурсы

- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [Kubero Documentation](https://kubero.dev/docs)
- [Casdoor Documentation](https://casdoor.org/docs/overview)
- [Gitea Documentation](https://docs.gitea.com/)
- [CloudNativePG Documentation](https://cloudnative-pg.io/)

