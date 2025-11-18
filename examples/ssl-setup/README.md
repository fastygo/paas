# Настройка SSL/TLS для Envoy Gateway

Этот каталог содержит конфигурации для настройки SSL/TLS сертификатов для Envoy Gateway.

## Файлы

- `dashboard-gateway-ssl.yaml` - Полная конфигурация Gateway с SSL для Dashboard
- `cert-manager-setup.sh` - Скрипт автоматической установки Cert-Manager
- `README.md` - Этот файл

## Быстрый старт

### 1. Установка Cert-Manager

```bash
# Автоматическая установка
chmod +x cert-manager-setup.sh
./cert-manager-setup.sh your-email@example.com

# Или вручную
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### 2. Создание ClusterIssuer

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### 3. Применение конфигурации Gateway

```bash
# Отредактируйте dashboard-gateway-ssl.yaml:
# - Замените "example.dash.net" на ваш домен
# - Убедитесь, что gatewayClassName правильный (eg)
# - Проверьте имя Service для Dashboard

kubectl apply -f dashboard-gateway-ssl.yaml
```

### 4. Проверка

```bash
# Проверьте статус Certificate
kubectl describe certificate dashboard-tls-cert -n kubernetes-dashboard

# Проверьте Gateway
kubectl describe gateway dashboard-gateway -n kubernetes-dashboard

# Проверьте HTTPRoute
kubectl get httproute -n kubernetes-dashboard

# Проверьте SSL сертификат
curl -vI https://example.dash.net
```

## Адаптация для вашего Dashboard

### Изменения в конфигурации

1. **Домен:** Замените `example.dash.net` на ваш домен
2. **Namespace:** Убедитесь, что namespace правильный (обычно `kubernetes-dashboard`)
3. **Service name:** Проверьте имя Service для Dashboard:
   ```bash
   kubectl get service -n kubernetes-dashboard
   ```
4. **GatewayClass:** Убедитесь, что `eg` - правильное имя вашего GatewayClass:
   ```bash
   kubectl get gatewayclass
   ```

### Пример адаптации

```yaml
# В dashboard-gateway-ssl.yaml замените:
hostname: "example.dash.net"  # → ваш домен
dnsNames:
- "example.dash.net"  # → ваш домен
- name: kubernetes-dashboard  # → имя вашего Service
```

## Troubleshooting

### Certificate не создается

```bash
# Проверьте события
kubectl get events -n kubernetes-dashboard --sort-by='.lastTimestamp'

# Проверьте Certificate статус
kubectl describe certificate dashboard-tls-cert -n kubernetes-dashboard

# Проверьте Challenge
kubectl get challenges -n kubernetes-dashboard
kubectl describe challenge <challenge-name> -n kubernetes-dashboard
```

### DNS не резолвится

```bash
# Проверьте DNS
dig example.dash.net

# Убедитесь, что DNS указывает на LoadBalancer IP
EXTERNAL_IP=$(kubectl get service -n envoy-gateway-system envoy-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "DNS должен указывать на: $EXTERNAL_IP"
```

### Gateway не принимает трафик

```bash
# Проверьте статус Gateway
kubectl describe gateway dashboard-gateway -n kubernetes-dashboard

# Проверьте HTTPRoute
kubectl describe httproute dashboard-route -n kubernetes-dashboard

# Проверьте логи Envoy Gateway
kubectl logs -n envoy-gateway-system -l app.kubernetes.io/name=gateway --tail=100
```

### SSL сертификат недействителен

```bash
# Проверьте Secret с сертификатом
kubectl get secret dashboard-tls-cert -n kubernetes-dashboard

# Проверьте содержимое сертификата
kubectl get secret dashboard-tls-cert -n kubernetes-dashboard -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

## Альтернативные варианты

### Self-Signed сертификаты (для тестирования)

```bash
# Создать self-signed сертификат
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout dashboard.key -out dashboard.crt \
  -subj "/CN=example.dash.net"

# Создать Secret
kubectl create secret tls dashboard-tls-cert \
  --cert=dashboard.crt \
  --key=dashboard.key \
  -n kubernetes-dashboard
```

### Использование существующих сертификатов

```bash
# Если у вас уже есть сертификаты
kubectl create secret tls dashboard-tls-cert \
  --cert=/path/to/certificate.crt \
  --key=/path/to/private.key \
  -n kubernetes-dashboard
```

## Дополнительные ресурсы

- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Envoy Gateway TLS](https://gateway.envoyproxy.io/latest/user/guides/tls/)
- [Gateway API TLS](https://gateway-api.sigs.k8s.io/references/spec/#gateway.networking.k8s.io/v1.GatewayTLSConfig)

