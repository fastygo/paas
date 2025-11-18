# Настройка SSL/TLS для Envoy Gateway в облаке

## Проблема

Облачный провайдер отдает дашборд без SSL. Нужно настроить HTTPS для безопасного доступа.

## Решения

### Вариант 1: Cert-Manager + Let's Encrypt (Рекомендуется)

Автоматическое получение и обновление бесплатных SSL сертификатов.

### Вариант 2: Self-Signed сертификаты

Для тестирования или внутренних сервисов.

### Вариант 3: Ручные сертификаты

Если у вас уже есть сертификаты от провайдера.

## Вариант 1: Cert-Manager + Let's Encrypt (Автоматические сертификаты)

### Шаг 1: Установка Cert-Manager

```bash
# Добавить Helm репозиторий
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Установить cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### Шаг 2: Настройка ClusterIssuer для Let's Encrypt

```yaml
# cert-manager-clusterissuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # Ваш email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    # HTTP-01 challenge (для Envoy Gateway)
    - http01:
        ingress:
          class: nginx  # Или ваш Ingress класс
    # Или DNS-01 challenge (если нужен wildcard)
    # - dns01:
    #     cloudflare:
    #       apiTokenSecretRef:
    #         name: cloudflare-api-token
    #         key: api-token
```

Применить:
```bash
kubectl apply -f cert-manager-clusterissuer.yaml
```

### Шаг 3: Миграция с Ingress на Gateway API

Ваша текущая конфигурация использует Ingress:

```yaml
# Старая конфигурация (Ingress)
app:
  ingress:
    enabled: true
    hosts:
      - example.dash.net
    useDefaultIngressClass: true
```

Новая конфигурация для Envoy Gateway:

```yaml
# Новая конфигурация (Gateway API)
---
# Gateway с HTTPS listener
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: dashboard-gateway
  namespace: default
spec:
  gatewayClassName: eg  # Ваш GatewayClass
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "example.dash.net"
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "example.dash.net"
    allowedRoutes:
      namespaces:
        from: All
    tls:
      mode: Terminate
      certificateRefs:
      - name: dashboard-tls-cert
        namespace: default

---
# Certificate для автоматического получения SSL
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: dashboard-tls-cert
  namespace: default
spec:
  secretName: dashboard-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "example.dash.net"
  - "*.dash.net"  # Если нужен wildcard

---
# HTTPRoute для дашборда
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: dashboard-route
  namespace: default
spec:
  parentRefs:
  - name: dashboard-gateway
    namespace: default
  hostnames:
  - "example.dash.net"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: dashboard-web-service  # Ваш Service для dashboard
      port: 80
      weight: 100
```

### Шаг 4: HTTP → HTTPS редирект

```yaml
# HTTPRoute для редиректа HTTP на HTTPS
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: dashboard-redirect
  namespace: default
spec:
  parentRefs:
  - name: dashboard-gateway
    namespace: default
  hostnames:
  - "example.dash.net"
  rules:
  - filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        statusCode: 301
    matches:
    - path:
        type: PathPrefix
        value: /
```

## Вариант 2: Self-Signed сертификаты (для тестирования)

### Создание Self-Signed сертификата

```bash
# Создать приватный ключ
openssl genrsa -out dashboard.key 2048

# Создать CSR
openssl req -new -key dashboard.key -out dashboard.csr \
  -subj "/CN=example.dash.net"

# Создать самоподписанный сертификат
openssl x509 -req -days 365 -in dashboard.csr -signkey dashboard.key \
  -out dashboard.crt

# Создать Secret в Kubernetes
kubectl create secret tls dashboard-tls-cert \
  --cert=dashboard.crt \
  --key=dashboard.key \
  -n default
```

### Использование в Gateway

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: dashboard-gateway
spec:
  gatewayClassName: eg
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "example.dash.net"
    tls:
      mode: Terminate
      certificateRefs:
      - name: dashboard-tls-cert
        namespace: default
```

## Вариант 3: Ручные сертификаты от провайдера

Если у вас есть сертификаты от облачного провайдера:

```bash
# Создать Secret с сертификатами
kubectl create secret tls dashboard-tls-cert \
  --cert=/path/to/certificate.crt \
  --key=/path/to/private.key \
  -n default
```

Затем использовать в Gateway как в варианте 2.

## Адаптация вашей конфигурации Dashboard

### Текущая конфигурация (Ingress)

```yaml
app:
  ingress:
    enabled: true
    hosts:
      - example.dash.net
    useDefaultIngressClass: true
cert-manager:
  enabled: false
```

### Новая конфигурация (Gateway API)

Создайте файл `dashboard-gateway-config.yaml`:

```yaml
# Gateway для Dashboard
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: dashboard-gateway
  namespace: default
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "example.dash.net"
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "example.dash.net"
    tls:
      mode: Terminate
      certificateRefs:
      - name: dashboard-tls-cert
        namespace: default

---
# Certificate (если используете cert-manager)
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: dashboard-tls-cert
  namespace: default
spec:
  secretName: dashboard-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "example.dash.net"

---
# HTTPRoute для Dashboard
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: dashboard-route
  namespace: default
spec:
  parentRefs:
  - name: dashboard-gateway
  hostnames:
  - "example.dash.net"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: kubernetes-dashboard  # Имя вашего Service
      port: 443
      weight: 100

---
# Редирект HTTP → HTTPS
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: dashboard-redirect
  namespace: default
spec:
  parentRefs:
  - name: dashboard-gateway
  hostnames:
  - "example.dash.net"
  rules:
  - filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        statusCode: 301
    matches:
    - path:
        type: PathPrefix
        value: /
```

## Полная конфигурация для вашего Dashboard

Учитывая ваши образы из внутреннего registry:

```yaml
# dashboard-complete-config.yaml

---
# Gateway
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: dashboard-gateway
  namespace: kubernetes-dashboard
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "example.dash.net"
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "example.dash.net"
    tls:
      mode: Terminate
      certificateRefs:
      - name: dashboard-tls-cert
        namespace: kubernetes-dashboard

---
# Certificate (cert-manager)
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: dashboard-tls-cert
  namespace: kubernetes-dashboard
spec:
  secretName: dashboard-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "example.dash.net"

---
# HTTPRoute для Dashboard
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: dashboard-route
  namespace: kubernetes-dashboard
spec:
  parentRefs:
  - name: dashboard-gateway
    namespace: kubernetes-dashboard
  hostnames:
  - "example.dash.net"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: kubernetes-dashboard
      port: 443
      weight: 100

---
# Редирект HTTP → HTTPS
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: dashboard-redirect
  namespace: kubernetes-dashboard
spec:
  parentRefs:
  - name: dashboard-gateway
    namespace: kubernetes-dashboard
  hostnames:
  - "example.dash.net"
  rules:
  - filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        statusCode: 301
    matches:
    - path:
        type: PathPrefix
        value: /
```

## Пошаговая инструкция

### 1. Установите Cert-Manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Проверьте установку
kubectl get pods -n cert-manager
```

### 2. Создайте ClusterIssuer

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

### 3. Примените конфигурацию Gateway

```bash
kubectl apply -f dashboard-complete-config.yaml
```

### 4. Проверьте статус Certificate

```bash
# Проверьте статус сертификата
kubectl describe certificate dashboard-tls-cert -n kubernetes-dashboard

# Проверьте Secret
kubectl get secret dashboard-tls-cert -n kubernetes-dashboard

# Проверьте Gateway
kubectl describe gateway dashboard-gateway -n kubernetes-dashboard
```

### 5. Настройте DNS

```bash
# Получите External IP LoadBalancer
kubectl get service -n envoy-gateway-system envoy-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Настройте DNS запись:
# example.dash.net A <EXTERNAL_IP>
```

## Troubleshooting

### Сертификат не создается

```bash
# Проверьте события
kubectl get events -n kubernetes-dashboard --sort-by='.lastTimestamp'

# Проверьте Certificate статус
kubectl describe certificate dashboard-tls-cert -n kubernetes-dashboard

# Проверьте Challenge
kubectl get challenges -n kubernetes-dashboard
```

### DNS не резолвится

```bash
# Проверьте DNS
dig example.dash.net

# Проверьте, что DNS указывает на LoadBalancer IP
kubectl get service -n envoy-gateway-system envoy-gateway
```

### Gateway не принимает трафик

```bash
# Проверьте статус Gateway
kubectl describe gateway dashboard-gateway -n kubernetes-dashboard

# Проверьте HTTPRoute
kubectl describe httproute dashboard-route -n kubernetes-dashboard

# Проверьте логи Envoy Gateway
kubectl logs -n envoy-gateway-system -l app.kubernetes.io/name=gateway
```

## Альтернатива: Использование Ingress с Envoy Gateway

Если вы хотите временно использовать Ingress API вместо Gateway API:

```yaml
# Ingress с cert-manager аннотациями
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard-ingress
  namespace: kubernetes-dashboard
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx  # Или ваш Ingress класс
  tls:
  - hosts:
    - example.dash.net
    secretName: dashboard-tls-cert
  rules:
  - host: example.dash.net
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kubernetes-dashboard
            port:
              number: 443
```

Но рекомендуется использовать Gateway API для лучшей интеграции с Envoy Gateway.

## Рекомендации

1. ✅ **Используйте Cert-Manager** - автоматическое управление сертификатами
2. ✅ **Let's Encrypt** - бесплатные SSL сертификаты
3. ✅ **HTTP → HTTPS редирект** - для безопасности
4. ✅ **Gateway API** - вместо старого Ingress API
5. ✅ **Мониторинг** - отслеживайте срок действия сертификатов

## Заключение

Для настройки SSL/TLS в облаке с Envoy Gateway:

1. Установите Cert-Manager
2. Создайте ClusterIssuer для Let's Encrypt
3. Создайте Certificate ресурс
4. Настройте Gateway с HTTPS listener
5. Настройте HTTPRoute для маршрутизации
6. Настройте DNS на LoadBalancer IP

Все готово для безопасного HTTPS доступа к вашему дашборду!

