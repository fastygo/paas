# Интеграция Envoy Gateway с облачными Kubernetes кластерами

## Краткий ответ

**Да, вы сможете интегрировать Envoy Gateway без проблем**, но есть важные нюансы:

1. ✅ **Envoy Gateway и Ingress могут сосуществовать** - они используют разные API
2. ✅ **Gateway API - это будущее** - более мощный и гибкий стандарт
3. ⚠️ **Нужно правильно настроить** - чтобы избежать конфликтов
4. ✅ **Облачные провайдеры поддерживают** - через LoadBalancer Service

## Разница между Ingress и Gateway API

### Традиционный Ingress

```yaml
# Старый стандарт (Ingress API)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  ingressClassName: nginx  # или traefik, или cloud-provider
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

**Ограничения:**
- Простая маршрутизация
- Ограниченные возможности
- Зависит от контроллера (nginx, traefik, etc.)

### Gateway API (Envoy Gateway)

```yaml
# Новый стандарт (Gateway API)
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: eg  # Envoy Gateway
  listeners:
  - name: web
    protocol: HTTP
    port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: my-service
      port: 80
```

**Преимущества:**
- Более мощная маршрутизация
- Поддержка TLS, mTLS, rate limiting
- Лучшая изоляция (namespace-based)
- Стандартизированный API

## Совместимость с облачными провайдерами

### Как это работает в облаке

```
Internet
    │
    ▼
┌─────────────────────────────────────────┐
│  Cloud Load Balancer (Managed)          │
│  - DigitalOcean Load Balancer          │
│  - AWS ALB/NLB                         │
│  - GCP Load Balancer                   │
│  - Hetzner Load Balancer               │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│  Envoy Gateway Service (LoadBalancer)   │
│  - External IP от провайдера           │
│  - Порт 80/443                         │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│  Envoy Gateway Pods                     │
│  - Обработка Gateway API               │
│  - Маршрутизация трафика              │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│  Application Pods                       │
└─────────────────────────────────────────┘
```

## Интеграция по провайдерам

### DigitalOcean Kubernetes

**Поддержка:** ✅ Полная поддержка

```yaml
# Envoy Gateway Service с LoadBalancer
apiVersion: v1
kind: Service
metadata:
  name: envoy-gateway
  namespace: envoy-gateway-system
  annotations:
    service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-algorithm: "round_robin"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  - port: 443
    targetPort: 8443
    protocol: TCP
    name: https
  selector:
    app: envoy-gateway
```

**Особенности:**
- Автоматическое создание Load Balancer
- Поддержка HTTP/HTTPS
- Интеграция с DigitalOcean DNS

### Hetzner Cloud

**Поддержка:** ✅ Полная поддержка

```yaml
apiVersion: v1
kind: Service
metadata:
  name: envoy-gateway
  namespace: envoy-gateway-system
  annotations:
    loadbalancer.hetzner.cloud/type: "lb11"  # или lb21, lb31
    loadbalancer.hetzner.cloud/location: "nbg1"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: envoy-gateway
```

**Особенности:**
- Низкая стоимость Load Balancer
- Хорошая производительность
- Поддержка разных типов LB

### AWS EKS

**Поддержка:** ✅ Полная поддержка (через NLB или ALB)

```yaml
# Вариант 1: Network Load Balancer (рекомендуется)
apiVersion: v1
kind: Service
metadata:
  name: envoy-gateway
  namespace: envoy-gateway-system
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: envoy-gateway
```

**Особенности:**
- Поддержка NLB и ALB
- Интеграция с Route53
- Поддержка WAF

### GCP GKE

**Поддержка:** ✅ Полная поддержка

```yaml
apiVersion: v1
kind: Service
metadata:
  name: envoy-gateway
  namespace: envoy-gateway-system
  annotations:
    cloud.google.com/load-balancer-type: "External"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: envoy-gateway
```

## Сосуществование с Ingress

### Вариант 1: Разделение по namespace (рекомендуется)

```yaml
# Ingress контроллер в одном namespace
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-system
---
# Envoy Gateway в другом namespace
apiVersion: v1
kind: Namespace
metadata:
  name: envoy-gateway-system
```

**Преимущества:**
- Полная изоляция
- Нет конфликтов портов
- Легко управлять

### Вариант 2: Разные порты

```yaml
# Ingress на порту 80
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80

---
# Envoy Gateway на порту 8080
apiVersion: v1
kind: Service
metadata:
  name: envoy-gateway
spec:
  type: LoadBalancer
  ports:
  - port: 8080
    targetPort: 8080
```

### Вариант 3: Миграция постепенная

1. **Этап 1:** Запустить Envoy Gateway параллельно с Ingress
2. **Этап 2:** Мигрировать приложения по одному
3. **Этап 3:** Отключить Ingress после миграции

## Конфигурация Envoy Gateway для облака

### Базовая установка через Helm

```bash
# Добавить репозиторий
helm repo add eg-helm https://gateway.envoyproxy.io/helm
helm repo update

# Установить Envoy Gateway
helm install eg eg-helm/gateway-operator \
  -n envoy-gateway-system \
  --create-namespace
```

### Конфигурация GatewayClass

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: config.gateway.envoyproxy.io
    kind: EnvoyProxy
    name: default-envoy-proxy
  description: "Envoy Gateway for cloud deployment"
```

### Конфигурация Gateway с LoadBalancer

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: cloud-gateway
  namespace: default
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "*.example.com"
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "*.example.com"
    tls:
      mode: Terminate
      certificateRefs:
      - name: cloud-tls-cert
```

### Service для LoadBalancer

```yaml
apiVersion: v1
kind: Service
metadata:
  name: envoy-gateway
  namespace: envoy-gateway-system
  annotations:
    # Для DigitalOcean
    service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-algorithm: "round_robin"
    
    # Для Hetzner
    # loadbalancer.hetzner.cloud/type: "lb11"
    
    # Для AWS
    # service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  - port: 443
    targetPort: 8443
    protocol: TCP
    name: https
  selector:
    app.kubernetes.io/name: gateway
    app.kubernetes.io/component: proxy
```

## Ваша текущая конфигурация

Судя по вашему проекту, вы уже используете Envoy Gateway:

```yaml
# Из helmwave.yml
- name: "eg"
  chart:
    name: oci://docker.io/envoyproxy/gateway-helm
```

И у вас есть GatewayClass:

```yaml
# Из paas-system/templates/gateway.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: {{ .Values.gateway.className }}
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
```

## Адаптация для облака

### Обновление helmwave.yml для облака

```yaml
# helmwave-cloud.yml
releases:
  - name: "eg"
    chart:
      name: oci://docker.io/envoyproxy/gateway-helm
    <<: *options-system
    tags: [eg]
    values:
      - values/envoy-gateway-cloud.yaml  # Новый файл с настройками для облака
```

### values/envoy-gateway-cloud.yaml

```yaml
# Настройки Envoy Gateway для облачного развертывания

# Service тип LoadBalancer для облака
service:
  type: LoadBalancer
  annotations:
    # Для DigitalOcean
    service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-algorithm: "round_robin"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-path: "/healthz"
    
    # Для Hetzner (раскомментируйте если используете)
    # loadbalancer.hetzner.cloud/type: "lb11"
    # loadbalancer.hetzner.cloud/location: "nbg1"
    
    # Для AWS (раскомментируйте если используете)
    # service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    # service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
  
  ports:
    http:
      port: 80
      targetPort: 8080
    https:
      port: 443
      targetPort: 8443

# Ресурсы для облачного окружения
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "2000m"
    memory: "2Gi"

# Реплики для высокой доступности
replicaCount: 2

# Node selector (если нужно разместить на определенных узлах)
nodeSelector: {}

# Tolerations (если узлы имеют taints)
tolerations: []
```

## Возможные проблемы и решения

### Проблема 1: Конфликт портов с Ingress

**Решение:**
```yaml
# Используйте разные порты или разные LoadBalancer
# Ingress: порт 80
# Envoy Gateway: порт 8080 (или другой)
```

### Проблема 2: LoadBalancer не создается

**Решение:**
```bash
# Проверьте аннотации для вашего провайдера
kubectl describe service envoy-gateway -n envoy-gateway-system

# Проверьте события
kubectl get events -n envoy-gateway-system
```

### Проблема 3: Gateway API не поддерживается

**Решение:**
```bash
# Проверьте версию Kubernetes (нужна 1.24+)
kubectl version

# Установите Gateway API CRD
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

### Проблема 4: TLS сертификаты

**Решение:**
```yaml
# Используйте cert-manager для автоматических сертификатов
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cloud-tls-cert
spec:
  secretName: cloud-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "*.example.com"
```

## Миграция с Ingress на Gateway API

### Пошаговый план

1. **Установите Envoy Gateway** параллельно с Ingress
2. **Создайте Gateway** ресурс
3. **Мигрируйте приложения** по одному:
   ```yaml
   # Старый Ingress
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   # ...
   
   # Новый HTTPRoute
   apiVersion: gateway.networking.k8s.io/v1
   kind: HTTPRoute
   # ...
   ```
4. **Проверьте работу** каждого приложения
5. **Отключите Ingress** после миграции всех приложений

## Рекомендации

### Для начала в облаке:

1. ✅ **Используйте Envoy Gateway** - это современный стандарт
2. ✅ **Настройте LoadBalancer Service** - для внешнего доступа
3. ✅ **Используйте Gateway API** - вместо старого Ingress
4. ✅ **Настройте TLS** - через cert-manager
5. ✅ **Мониторьте** - используйте метрики Envoy

### Для вашего проекта:

Ваша текущая конфигурация уже готова для облака! Нужно только:

1. Обновить Service тип на LoadBalancer
2. Добавить аннотации для вашего облачного провайдера
3. Настроить DNS на LoadBalancer IP

## Заключение

**Да, вы сможете интегрировать Envoy Gateway без проблем!**

- ✅ Gateway API и Ingress могут сосуществовать
- ✅ Облачные провайдеры поддерживают LoadBalancer
- ✅ Ваша текущая конфигурация совместима
- ✅ Нужно только добавить правильные аннотации для LoadBalancer

Envoy Gateway - это отличный выбор для облачного развертывания, так как он:
- Использует современный Gateway API стандарт
- Более мощный, чем традиционный Ingress
- Хорошо интегрируется с облачными провайдерами
- Поддерживает продвинутые функции (mTLS, rate limiting, etc.)

