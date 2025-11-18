#!/bin/bash
# Скрипт для установки Cert-Manager и настройки SSL для Dashboard
# Использование: ./cert-manager-setup.sh your-email@example.com

set -e

EMAIL=${1:-""}

if [ -z "$EMAIL" ]; then
    echo "Usage: $0 <your-email@example.com>"
    echo "Example: $0 admin@example.com"
    exit 1
fi

echo "=== Установка Cert-Manager и настройка SSL ==="
echo "Email: $EMAIL"
echo ""

# Проверка Helm
if ! command -v helm &> /dev/null; then
    echo "❌ Helm не установлен. Установите Helm сначала."
    exit 1
fi

echo "✅ Helm найден"

# Добавление Helm репозитория
echo "📦 Добавление Helm репозитория Cert-Manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Установка Cert-Manager
echo "📦 Установка Cert-Manager..."
if helm list -n cert-manager | grep -q cert-manager; then
    echo "⚠️  Cert-Manager уже установлен. Обновление..."
    helm upgrade cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --set installCRDs=true
else
    helm install cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --set installCRDs=true
fi

# Ожидание готовности
echo "⏳ Ожидание готовности Cert-Manager..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Создание ClusterIssuer
echo "📝 Создание ClusterIssuer для Let's Encrypt..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Создание ClusterIssuer для staging (для тестирования)
echo "📝 Создание ClusterIssuer для Let's Encrypt Staging (тестирование)..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Проверка ClusterIssuer
echo "✅ Проверка ClusterIssuer..."
kubectl get clusterissuer

echo ""
echo "=== Установка завершена ==="
echo ""
echo "Следующие шаги:"
echo "1. Примените конфигурацию Gateway с Certificate:"
echo "   kubectl apply -f dashboard-gateway-ssl.yaml"
echo ""
echo "2. Проверьте статус Certificate:"
echo "   kubectl describe certificate dashboard-tls-cert -n kubernetes-dashboard"
echo ""
echo "3. Настройте DNS на External IP LoadBalancer:"
echo "   kubectl get service -n envoy-gateway-system envoy-gateway"
echo ""
echo "4. Проверьте SSL сертификат:"
echo "   curl -vI https://example.dash.net"

