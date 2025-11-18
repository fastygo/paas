# Интеграция Envoy Gateway с облачными Kubernetes кластерами

Этот каталог содержит примеры конфигураций для развертывания Envoy Gateway в облачных Kubernetes кластерах.

## Файлы

- `envoy-gateway-cloud-values.yaml` - Values для Helm установки Envoy Gateway
- `gateway-cloud-example.yaml` - Примеры Gateway и HTTPRoute конфигураций
- `README.md` - Этот файл

## Быстрый старт

### 1. Установка Envoy Gateway через Helm

```bash
# Добавить репозиторий
helm repo add eg-helm https://gateway.envoyproxy.io/helm
helm repo update

# Установить с cloud values
helm install eg eg-helm/gateway-operator \
  -n envoy-gateway-system \
  --create-namespace \
  -f envoy-gateway-cloud-values.yaml
```

### 2. Проверка LoadBalancer

```bash
# Дождитесь получения External IP
kubectl get service -n envoy-gateway-system

# Проверьте статус Gateway
kubectl get gateway -A
```

### 3. Создание Gateway

```bash
# Примените пример Gateway
kubectl apply -f gateway-cloud-example.yaml

# Проверьте статус
kubectl describe gateway cloud-gateway
```

### 4. Настройка DNS

```bash
# Получите External IP LoadBalancer
EXTERNAL_IP=$(kubectl get service -n envoy-gateway-system envoy-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Настройте DNS запись на этот IP
# Например: app.example.com -> $EXTERNAL_IP
```

## Настройка по провайдерам

### DigitalOcean

Используйте значения из `envoy-gateway-cloud-values.yaml` (уже настроено).

### Hetzner Cloud

Раскомментируйте секцию Hetzner в `envoy-gateway-cloud-values.yaml`:

```yaml
annotations:
  loadbalancer.hetzner.cloud/type: "lb11"
  loadbalancer.hetzner.cloud/location: "nbg1"
```

### AWS EKS

Раскомментируйте секцию AWS:

```yaml
annotations:
  service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
  service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
```

### GCP GKE

Раскомментируйте секцию GCP:

```yaml
annotations:
  cloud.google.com/load-balancer-type: "External"
```

## Интеграция с вашим проектом

### Обновление helmwave.yml

```yaml
# Добавьте values файл для облака
releases:
  - name: "eg"
    chart:
      name: oci://docker.io/envoyproxy/gateway-helm
    <<: *options-system
    tags: [eg]
    values:
      - "values/envoy-gateway-cloud.yaml"  # Новый файл
```

### Создание values/envoy-gateway-cloud.yaml

Скопируйте содержимое `envoy-gateway-cloud-values.yaml` и адаптируйте под ваш провайдер.

## Проверка работы

```bash
# Проверьте статус Gateway
kubectl get gateway -A

# Проверьте HTTPRoute
kubectl get httproute -A

# Проверьте логи Envoy Gateway
kubectl logs -n envoy-gateway-system -l app.kubernetes.io/name=gateway

# Проверьте метрики (если включены)
kubectl port-forward -n envoy-gateway-system svc/envoy-gateway-metrics 9090:9090
```

## Troubleshooting

### LoadBalancer не получает IP

```bash
# Проверьте события
kubectl get events -n envoy-gateway-system --sort-by='.lastTimestamp'

# Проверьте аннотации Service
kubectl describe service -n envoy-gateway-system envoy-gateway

# Проверьте совместимость провайдера
kubectl get nodes -o wide
```

### Gateway не принимает трафик

```bash
# Проверьте статус Gateway
kubectl describe gateway cloud-gateway

# Проверьте HTTPRoute
kubectl describe httproute example-app-route

# Проверьте Service приложения
kubectl get service example-app-service
```

### TLS не работает

```bash
# Убедитесь, что cert-manager установлен
kubectl get crd certificates.cert-manager.io

# Проверьте Certificate
kubectl describe certificate cloud-tls-cert

# Проверьте Secret с сертификатом
kubectl get secret cloud-tls-cert
```

## Дополнительные ресурсы

- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [Gateway API Specification](https://gateway-api.sigs.k8s.io/)
- [DigitalOcean Load Balancer](https://docs.digitalocean.com/products/networking/load-balancers/)
- [Hetzner Load Balancer](https://docs.hetzner.com/cloud/load-balancers/)

