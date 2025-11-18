#!/bin/bash
# Скрипт для быстрой настройки локального Kubernetes окружения
# Использование: ./setup-local-k8s.sh

set -e

echo "=== Настройка локального Kubernetes окружения ==="

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен. Установите Docker сначала."
    exit 1
fi

echo "✅ Docker найден"

# Установка Kind
if ! command -v kind &> /dev/null; then
    echo "📦 Установка Kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    echo "✅ Kind установлен"
else
    echo "✅ Kind уже установлен"
fi

# Установка kubectl
if ! command -v kubectl &> /dev/null; then
    echo "📦 Установка kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    echo "✅ kubectl установлен"
else
    echo "✅ kubectl уже установлен"
fi

# Установка Helm
if ! command -v helm &> /dev/null; then
    echo "📦 Установка Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✅ Helm установлен"
else
    echo "✅ Helm уже установлен"
fi

# Создание кластера
if kind get clusters | grep -q "learning"; then
    echo "⚠️  Кластер 'learning' уже существует"
    read -p "Удалить существующий кластер? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kind delete cluster --name learning
        echo "✅ Старый кластер удален"
    else
        echo "Пропускаем создание кластера"
        exit 0
    fi
fi

echo "📦 Создание Kind кластера..."
if [ -f "kind-cluster-config.yaml" ]; then
    kind create cluster --config kind-cluster-config.yaml --name learning
else
    kind create cluster --name learning
fi

echo "✅ Кластер создан"

# Ожидание готовности
echo "⏳ Ожидание готовности кластера..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Проверка
echo ""
echo "=== Проверка кластера ==="
kubectl get nodes
kubectl cluster-info

echo ""
echo "✅ Локальное Kubernetes окружение готово!"
echo ""
echo "Следующие шаги:"
echo "1. Проверьте кластер: kubectl get nodes"
echo "2. Установите Kubero: helm install kubero kubero/kubero -n kubero-system --create-namespace"
echo "3. Откройте UI: kubectl port-forward -n kubero-system svc/kubero-ui 8080:80"

