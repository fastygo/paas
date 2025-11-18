# Примеры интеграции Kubero с VPS узлами

Этот каталог содержит примеры конфигураций для интеграции Kubero с VPS узлами и автоматического управления ими.

## Файлы

### 1. `vps-node-crd.yaml`
Custom Resource Definition для управления VPS узлами. Определяет схему ресурса `VPSNode`, который описывает желаемое состояние пула VPS узлов.

**Использование:**
```bash
kubectl apply -f vps-node-crd.yaml
```

### 2. `vps-node-example.yaml`
Примеры использования VPSNode CRD для различных провайдеров:
- Hetzner Cloud с автомасштабированием
- DigitalOcean с автомасштабированием
- Vultr без автомасштабирования

**Использование:**
```bash
kubectl apply -f vps-node-example.yaml
```

### 3. `kuberoapp-with-node-selector.yaml`
Примеры KuberoApp с настройками размещения:
- Приложение на VPS узлах с nodeSelector и affinity
- Приложение на облачных узлах

**Использование:**
```bash
kubectl apply -f kuberoapp-with-node-selector.yaml
```

### 4. `mutating-webhook.yaml`
Конфигурация Mutating Admission Webhook для автоматического добавления nodeSelector и tolerations к KuberoApp при создании.

**Использование:**
```bash
# Сначала создайте сертификаты для webhook
# Затем примените конфигурацию
kubectl apply -f mutating-webhook.yaml
```

## Требования

1. **Kubernetes кластер** с поддержкой CRD и Admission Webhooks
2. **Kubero** установленный в кластере
3. **Оператор для VPSNode** (нужно разработать отдельно)
4. **Webhook сервер** (нужно разработать отдельно)

## Следующие шаги

1. Разработайте оператор для VPSNode CRD (см. примеры в `KUBERO_CUSTOMIZATION.md`)
2. Разработайте webhook сервер для автоматического добавления nodeSelector
3. Интегрируйте с API провайдеров VPS (Hetzner, DigitalOcean, etc.)
4. Настройте мониторинг и метрики для автомасштабирования

## Дополнительные ресурсы

- [Kubernetes CRD Documentation](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)
- [Kubebuilder Documentation](https://book.kubebuilder.io/)
- [Kubernetes Admission Webhooks](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)

