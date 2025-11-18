# Руководство по началу работы с Kubernetes и Kubero

## Рекомендация: Поэтапный подход

### Этап 1: Локальное изучение (1-2 недели)
**Начните локально** для понимания основ Kubernetes и Kubero

### Этап 2: Облачный кластер (после понимания основ)
**Переходите в облако** для production-ready окружения

### Этап 3: Масштабирование (по мере необходимости)
**Расширяйте** по мере роста нагрузки

## Почему начать локально?

### Преимущества локального старта:

1. **Быстрое обучение** - мгновенная обратная связь, нет задержек сети
2. **Низкая стоимость** - бесплатно для обучения
3. **Полный контроль** - можете экспериментировать без ограничений
4. **Безопасность** - ошибки не влияют на production
5. **Понимание основ** - лучше понимаете, что происходит под капотом

### Недостатки локального старта:

1. **Ограниченные ресурсы** - зависит от вашего компьютера
2. **Не production-ready** - отличается от реального окружения
3. **Нет высокой доступности** - один узел

## Варианты локального развертывания

### Вариант 1: Kind (Kubernetes in Docker) - Рекомендуется

**Плюсы:**
- Легко установить
- Работает на любом компьютере
- Можно создать multi-node кластер
- Близко к реальному Kubernetes

**Минусы:**
- Требует Docker
- Больше потребление ресурсов

### Вариант 2: Minikube

**Плюсы:**
- Официальный инструмент Kubernetes
- Хорошая документация
- Поддержка разных драйверов

**Минусы:**
- Один узел по умолчанию
- Может быть медленнее

### Вариант 3: K3s (легковесный Kubernetes)

**Плюсы:**
- Очень легковесный
- Быстрый запуск
- Хорош для разработки

**Минусы:**
- Упрощенная версия Kubernetes
- Может отличаться от production

## План обучения

### Неделя 1: Основы Kubernetes локально

#### День 1-2: Установка и первые шаги

```bash
# Установка Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Создание кластера
kind create cluster --name learning

# Проверка
kubectl get nodes
kubectl cluster-info
```

#### День 3-4: Основные концепции

- Pods, Deployments, Services
- ConfigMaps, Secrets
- Namespaces
- Основные команды kubectl

#### День 5-7: Практика с простыми приложениями

- Развертывание простого веб-приложения
- Настройка Service для доступа
- Использование ConfigMap для конфигурации

### Неделя 2: Kubero локально

#### День 1-2: Установка Kubero

```bash
# Установка через Helm
helm repo add kubero https://charts.kubero.dev
helm install kubero kubero/kubero -n kubero-system --create-namespace
```

#### День 3-4: Первое приложение в Kubero

- Создание Pipeline
- Создание App через UI
- Понимание CRD (KuberoApp, KuberoPipeline)

#### День 5-7: Интеграция с Gitea

- Установка Gitea локально (Docker Compose)
- Настройка webhook в Gitea
- Автоматический деплой при push

## Облачный Kubernetes: Гибкость и масштабирование

### Миф: "Облако не дает гибкости"

**Реальность:** Облачный Kubernetes дает БОЛЬШЕ гибкости:

1. **Автомасштабирование узлов** - автоматически добавляет/удаляет узлы
2. **Гибкие типы инстансов** - можно выбрать под задачу
3. **Multi-zone deployment** - высокая доступность
4. **Управляемые сервисы** - меньше рутинной работы
5. **Интеграция с облачными сервисами** - Load Balancer, Storage, etc.

### Когда переходить в облако?

**Переходите когда:**
- ✅ Понимаете основы Kubernetes
- ✅ Знаете, как работают Pods, Deployments, Services
- ✅ Можете развернуть простое приложение локально
- ✅ Готовы к production окружению

## Ваша целевая архитектура

### Компоненты системы:

```
┌─────────────────────────────────────────────────────────┐
│                    Frontend Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Gitea UI   │  │ CodeSandbox  │  │  User Apps   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                        │
┌─────────────────────────────────────────────────────────┐
│                  Authentication Layer                     │
│  ┌──────────────┐  ┌──────────────┐                    │
│  │     IAM      │  │     SSO      │                    │
│  │  (Casdoor)   │  │  (OAuth2)    │                    │
│  └──────────────┘  └──────────────┘                    │
└─────────────────────────────────────────────────────────┘
                        │
┌─────────────────────────────────────────────────────────┐
│                  Application Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Gitea      │  │ CodeSandbox  │  │ User Apps    │  │
│  │  (Backend)   │  │  Containers  │  │ Containers   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                        │
┌─────────────────────────────────────────────────────────┐
│                    Data Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ PostgreSQL   │  │ PostgreSQL   │  │ PostgreSQL   │  │
│  │  (Gitea DB)  │  │ (App DB #1)  │  │ (App DB #2)  │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Поэтапный план развертывания

### Фаза 1: Локальное изучение (2-3 недели)

#### Неделя 1: Kubernetes основы
- Установка Kind/Minicube
- Изучение основных концепций
- Развертывание простых приложений

#### Неделя 2: Kubero
- Установка Kubero локально
- Создание первого приложения
- Понимание Pipelines и Phases

#### Неделя 3: Интеграции
- Gitea локально (Docker Compose)
- Настройка webhook
- Автоматический деплой

### Фаза 2: Прототип в облаке (1-2 недели)

#### Начало с managed Kubernetes:
- **DigitalOcean Kubernetes** (рекомендуется для начала)
  - Простой в использовании
  - Низкая стоимость ($12/месяц за кластер)
  - Хорошая документация
  
- **Hetzner Cloud** (альтернатива)
  - Дешевле ($5-10/месяц)
  - Больше контроля
  
- **AWS EKS / GCP GKE / Azure AKS**
  - Для production масштаба
  - Больше функций
  - Выше стоимость

#### Развертывание компонентов:
1. **Kubero** - управление приложениями
2. **Gitea** - через Kubero или Helm
3. **IAM (Casdoor)** - через Kubero
4. **PostgreSQL** - через CloudNativePG или managed service

### Фаза 3: Production setup (2-4 недели)

#### Разделение окружений:
- Dev окружение
- Production окружение
- CI/CD интеграция

#### Масштабирование:
- Автомасштабирование приложений
- Автомасштабирование узлов
- Мониторинг и алертинг

## Рекомендуемый стек для начала

### Локально (Docker Compose для изучения)

```yaml
# docker-compose.local.yml
version: '3.8'
services:
  # Gitea для изучения
  gitea:
    image: gitea/gitea:latest
    ports:
      - "3000:3000"
      - "2222:22"
    volumes:
      - gitea_data:/data
    environment:
      - USER_UID=1000
      - USER_GID=1000
  
  # PostgreSQL для Gitea
  gitea-db:
    image: postgres:15
    environment:
      POSTGRES_DB: gitea
      POSTGRES_USER: gitea
      POSTGRES_PASSWORD: gitea
    volumes:
      - gitea_db_data:/var/lib/postgresql/data

volumes:
  gitea_data:
  gitea_db_data:
```

### В Kubernetes (после изучения основ)

Используйте Kubero для управления всеми компонентами через UI или CRD.

## Сравнение подходов

| Критерий | Локально (Kind) | Облачный Managed K8s |
|----------|----------------|----------------------|
| **Стоимость** | Бесплатно | $10-50/месяц |
| **Скорость обучения** | Быстро | Средне |
| **Production-ready** | Нет | Да |
| **Автомасштабирование** | Ручное | Автоматическое |
| **Высокая доступность** | Нет | Да |
| **Управление инфраструктурой** | Вы делаете все | Провайдер делает |
| **Гибкость масштабирования** | Ограничена | Высокая |

## Конкретный план действий

### День 1-3: Подготовка локального окружения

```bash
# 1. Установите Docker (если еще нет)
# 2. Установите Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# 3. Установите kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# 4. Создайте кластер
kind create cluster --name learning

# 5. Проверьте
kubectl get nodes
```

### День 4-7: Изучение Kubernetes

```bash
# Разверните простое приложение
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get pods,services

# Изучите основные ресурсы
kubectl explain pod
kubectl explain deployment
kubectl explain service
```

### Неделя 2: Kubero

```bash
# Установите Helm (если еще нет)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Установите Kubero
helm repo add kubero https://charts.kubero.dev
helm install kubero kubero/kubero -n kubero-system --create-namespace

# Откройте UI
kubectl port-forward -n kubero-system svc/kubero-ui 8080:80
# Откройте http://localhost:8080
```

### Неделя 3: Интеграция с Gitea

1. Установите Gitea локально через Docker Compose
2. Создайте репозиторий
3. Настройте webhook в Kubero
4. Сделайте push и посмотрите автоматический деплой

### Неделя 4: Переход в облако

1. Создайте аккаунт в DigitalOcean (или другом провайдере)
2. Создайте managed Kubernetes кластер
3. Подключитесь: `kubectl config use-context <cluster-name>`
4. Разверните те же компоненты, что локально

## Ответы на ваши вопросы

### "Где лучше развернуть Gitea и первый инстанс Kubero?"

**Рекомендация:**
1. **Gitea** - сначала локально через Docker Compose для изучения
2. **Kubero** - сначала локально через Kind для понимания
3. **Затем** - оба в облачном Kubernetes для production

### "Облако не даст гибких возможностей для масштабирования?"

**Это миф!** Облачный Kubernetes дает БОЛЬШЕ гибкости:

- ✅ **Автомасштабирование узлов** - автоматически добавляет узлы при нагрузке
- ✅ **Гибкие типы инстансов** - можно выбрать под задачу
- ✅ **Multi-region** - развертывание в разных регионах
- ✅ **Управляемые сервисы** - меньше рутинной работы
- ✅ **Интеграция с облачными сервисами** - Load Balancer, Storage, CDN

### "Я не знаком с K8s, понимаю только Docker Compose"

**Это нормально!** Kubernetes - это "Docker Compose для production":

- **Docker Compose** = один сервер, простые приложения
- **Kubernetes** = много серверов, сложные приложения, автомасштабирование

**Переход будет плавным:**
- Pods похожи на containers в Docker Compose
- Deployments похожи на services в Docker Compose
- Services похожи на ports в Docker Compose

## Следующие шаги

1. **Сегодня:** Установите Kind и создайте первый кластер
2. **Эта неделя:** Изучите основы Kubernetes
3. **Следующая неделя:** Установите Kubero локально
4. **Через 2 недели:** Переходите в облако

## Полезные ресурсы

- [Kubernetes Basics Tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kubero Documentation](https://kubero.dev/docs)
- [DigitalOcean Kubernetes Tutorial](https://www.digitalocean.com/community/tutorials/an-introduction-to-kubernetes)

