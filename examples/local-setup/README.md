# Локальное окружение для изучения

Этот каталог содержит конфигурации для быстрого старта локального изучения Kubernetes и Kubero.

## Файлы

- `docker-compose-gitea.yml` - Gitea локально через Docker Compose
- `kind-cluster-config.yaml` - Конфигурация Kind кластера
- `setup-local-k8s.sh` - Скрипт автоматической настройки

## Быстрый старт

### 1. Настройка Kubernetes кластера

```bash
# Запустите скрипт настройки
chmod +x setup-local-k8s.sh
./setup-local-k8s.sh
```

Или вручную:

```bash
# Установите Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Создайте кластер
kind create cluster --config kind-cluster-config.yaml --name learning

# Проверьте
kubectl get nodes
```

### 2. Установка Kubero

```bash
# Добавьте Helm репозиторий
helm repo add kubero https://charts.kubero.dev
helm repo update

# Установите Kubero
helm install kubero kubero/kubero -n kubero-system --create-namespace

# Дождитесь готовности
kubectl wait --for=condition=ready pod -l app=kubero -n kubero-system --timeout=300s

# Откройте UI
kubectl port-forward -n kubero-system svc/kubero-ui 8080:80
```

Откройте http://localhost:8080 в браузере.

### 3. Установка Gitea локально (для изучения)

```bash
# Запустите Gitea через Docker Compose
docker-compose -f docker-compose-gitea.yml up -d

# Откройте http://localhost:3000
# Первая настройка:
# - Database: PostgreSQL
# - Host: db:5432
# - User: gitea
# - Password: gitea
# - Database Name: gitea
```

### 4. Интеграция Gitea с Kubero

1. В Gitea создайте репозиторий
2. В Kubero создайте Pipeline с Git репозиторием
3. Настройте webhook в Gitea для автоматического деплоя

## Полезные команды

```bash
# Просмотр подов
kubectl get pods -A

# Просмотр сервисов
kubectl get services -A

# Логи приложения
kubectl logs -f <pod-name> -n <namespace>

# Описание ресурса
kubectl describe <resource-type> <resource-name>

# Удаление кластера (когда закончите)
kind delete cluster --name learning
```

## Следующие шаги

После изучения локально:

1. Переходите в облачный Kubernetes (DigitalOcean, Hetzner, etc.)
2. Разверните те же компоненты в облаке
3. Настройте CI/CD через Gitea Actions или Drone CI
4. Масштабируйте по мере необходимости

## Ресурсы

- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [Kubero Documentation](https://kubero.dev/docs)

