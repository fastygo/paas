# Анализ возможностей кастомизации Kubero

## Введение

Kubero - это Kubernetes оператор, использующий Custom Resource Definitions (CRD) для управления приложениями. Его архитектура позволяет значительную кастомизацию через стандартные механизмы Kubernetes.

## Архитектура Kubero

### Основные компоненты

1. **KuberoApp CRD** - определяет приложения
2. **KuberoPipeline CRD** - определяет пайплайны развертывания
3. **Kubero Operator** - контроллер, который обрабатывает CRD и создает Kubernetes ресурсы
4. **UI (Vue.js)** - веб-интерфейс для управления

### Как работает Kubero

```
User → UI/API → KuberoApp/KuberoPipeline CRD → Kubero Operator → Kubernetes Resources
                                                                    (Deployments, Services, etc.)
```

## Возможности кастомизации

### 1. Управление узлами через Kubernetes механизмы

Kubero **не управляет узлами напрямую**, но использует стандартные механизмы Kubernetes для размещения подов:

#### Node Selectors и Node Affinity

Вы можете кастомизировать размещение приложений через стандартные Kubernetes механизмы:

```yaml
# Пример кастомизации KuberoApp через nodeSelector
apiVersion: kubero.dev/v1alpha1
kind: KuberoApp
metadata:
  name: my-app
spec:
  # ... другие настройки
  nodeSelector:
    node-type: vps
    paas-tier: tenant
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-type
            operator: In
            values:
            - vps
          - key: provider
            operator: In
            values:
            - vps-provider-1
            - vps-provider-2
```

#### Taints и Tolerations

```yaml
apiVersion: kubero.dev/v1alpha1
kind: KuberoApp
metadata:
  name: my-app
spec:
  tolerations:
  - key: paas-tier
    operator: Equal
    value: tenant
    effect: NoSchedule
  - key: node-type
    operator: Equal
    value: vps
    effect: PreferNoSchedule
```

### 2. Расширение CRD схемы

#### Создание кастомных полей в KuberoApp

Вы можете расширить CRD KuberoApp, добавив свои поля:

```yaml
# kuberoapp-custom.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: kuberoapps.kubero.dev
spec:
  group: kubero.dev
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              # Стандартные поля Kubero
              name:
                type: string
              # Ваши кастомные поля
              customNodeSelector:
                type: object
                properties:
                  provider:
                    type: string
                  region:
                    type: string
                  instanceType:
                    type: string
              autoScaling:
                type: object
                properties:
                  enabled:
                    type: boolean
                  minNodes:
                    type: integer
                  maxNodes:
                    type: integer
                  targetCPU:
                    type: integer
```

### 3. Создание кастомного оператора для управления узлами

Вы можете создать собственный оператор, который будет:

#### Автоматически добавлять VPS узлы в кластер

```go
// Пример кастомного оператора для управления VPS узлами
package main

import (
    "context"
    "fmt"
    
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/tools/clientcmd"
)

type VPSNodeManager struct {
    clientset *kubernetes.Clientset
}

func (v *VPSNodeManager) AddVPSNode(provider string, region string, instanceType string) error {
    // 1. Создать VPS через API провайдера
    vpsIP, err := v.createVPS(provider, region, instanceType)
    if err != nil {
        return err
    }
    
    // 2. Подготовить VPS (установить Kubernetes компоненты)
    err = v.prepareVPS(vpsIP)
    if err != nil {
        return err
    }
    
    // 3. Присоединить к кластеру
    err = v.joinToCluster(vpsIP)
    if err != nil {
        return err
    }
    
    // 4. Настроить labels и taints
    nodeName := fmt.Sprintf("vps-%s-%s", provider, region)
    err = v.configureNode(nodeName, provider, region)
    if err != nil {
        return err
    }
    
    return nil
}

func (v *VPSNodeManager) configureNode(nodeName, provider, region string) error {
    node, err := v.clientset.CoreV1().Nodes().Get(context.TODO(), nodeName, metav1.GetOptions{})
    if err != nil {
        return err
    }
    
    // Добавить labels
    node.Labels["provider"] = provider
    node.Labels["region"] = region
    node.Labels["node-type"] = "vps"
    node.Labels["paas-tier"] = "tenant"
    
    // Добавить taints
    node.Spec.Taints = append(node.Spec.Taints, corev1.Taint{
        Key:    "paas-tier",
        Value:  "tenant",
        Effect: corev1.TaintEffectNoSchedule,
    })
    
    _, err = v.clientset.CoreV1().Nodes().Update(context.TODO(), node, metav1.UpdateOptions{})
    return err
}
```

### 4. Интеграция с провайдерами VPS

#### Создание CRD для управления VPS узлами

```yaml
# vpsnode.kubero.dev.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: vpsnodes.kubero.dev
spec:
  group: kubero.dev
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              provider:
                type: string
                enum: ["hetzner", "digitalocean", "vultr", "linode"]
              region:
                type: string
              instanceType:
                type: string
              autoScale:
                type: object
                properties:
                  enabled:
                    type: boolean
                  minNodes:
                    type: integer
                  maxNodes:
                    type: integer
                  targetCPU:
                    type: integer
                    minimum: 0
                    maximum: 100
              labels:
                type: object
              taints:
                type: array
                items:
                  type: object
          status:
            type: object
            properties:
              nodeName:
                type: string
              state:
                type: string
                enum: ["creating", "joining", "ready", "failed"]
              ipAddress:
                type: string
  scope: Cluster
  names:
    plural: vpsnodes
    singular: vpsnode
    kind: VPSNode
```

#### Пример использования

```yaml
apiVersion: kubero.dev/v1alpha1
kind: VPSNode
metadata:
  name: vps-hetzner-fsn1
spec:
  provider: hetzner
  region: fsn1
  instanceType: cx21
  autoScale:
    enabled: true
    minNodes: 1
    maxNodes: 5
    targetCPU: 70
  labels:
    provider: hetzner
    region: fsn1
    node-type: vps
  taints:
  - key: paas-tier
    value: tenant
    effect: NoSchedule
```

### 5. Автомасштабирование узлов

#### Cluster Autoscaler интеграция

Kubero может работать с Cluster Autoscaler для автоматического масштабирования узлов:

```yaml
# cluster-autoscaler-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-config
  namespace: kube-system
data:
  config: |
    nodes:
    - name: vps-pool
      minSize: 1
      maxSize: 10
      instanceType: cx21
      provider: hetzner
      region: fsn1
      labels:
        node-type: vps
        paas-tier: tenant
      taints:
      - key: paas-tier
        value: tenant
        effect: NoSchedule
```

#### Кастомный оператор для автмасштабирования

```go
// Пример логики автмасштабирования
func (c *VPSNodeController) reconcileAutoScaling(ctx context.Context, vpsNode *VPSNode) error {
    if !vpsNode.Spec.AutoScale.Enabled {
        return nil
    }
    
    // Получить метрики использования CPU на VPS узлах
    cpuUsage, err := c.getCPUUsageForVPSNodes(vpsNode.Spec.Provider, vpsNode.Spec.Region)
    if err != nil {
        return err
    }
    
    // Получить текущее количество узлов
    currentNodeCount, err := c.getVPSNodeCount(vpsNode.Spec.Provider, vpsNode.Spec.Region)
    if err != nil {
        return err
    }
    
    // Логика масштабирования
    targetCPU := vpsNode.Spec.AutoScale.TargetCPU
    minNodes := vpsNode.Spec.AutoScale.MinNodes
    maxNodes := vpsNode.Spec.AutoScale.MaxNodes
    
    if cpuUsage > float64(targetCPU) && currentNodeCount < maxNodes {
        // Увеличить количество узлов
        return c.addVPSNode(vpsNode.Spec.Provider, vpsNode.Spec.Region, vpsNode.Spec.InstanceType)
    } else if cpuUsage < float64(targetCPU-20) && currentNodeCount > minNodes {
        // Уменьшить количество узлов (с учетом graceful shutdown)
        return c.removeVPSNode(vpsNode.Spec.Provider, vpsNode.Spec.Region)
    }
    
    return nil
}
```

### 6. Интеграция с Kubero через Webhooks

#### Mutating Admission Webhook

Вы можете создать Mutating Admission Webhook, который автоматически добавляет nodeSelector и tolerations к KuberoApp:

```go
// Пример Mutating Webhook для KuberoApp
func (w *KuberoAppWebhook) mutateKuberoApp(app *KuberoApp) {
    // Автоматически добавлять nodeSelector на основе labels приложения
    if app.Labels["tier"] == "tenant" {
        if app.Spec.NodeSelector == nil {
            app.Spec.NodeSelector = make(map[string]string)
        }
        app.Spec.NodeSelector["paas-tier"] = "tenant"
        app.Spec.NodeSelector["node-type"] = "vps"
    }
    
    // Автоматически добавлять tolerations
    if len(app.Spec.Tolerations) == 0 {
        app.Spec.Tolerations = []corev1.Toleration{
            {
                Key:      "paas-tier",
                Operator: corev1.TolerationOpEqual,
                Value:     "tenant",
                Effect:   corev1.TaintEffectNoSchedule,
            },
        }
    }
}
```

### 7. Кастомизация через Helm Values

Если Kubero установлен через Helm, вы можете кастомизировать его поведение:

```yaml
# values-custom.yaml
kubero:
  operator:
    # Кастомные настройки оператора
    nodeSelector:
      node-type: cloud
    tolerations: []
    
  # Настройки по умолчанию для приложений
  defaultAppConfig:
    nodeSelector:
      node-type: vps
    tolerations:
    - key: paas-tier
      value: tenant
      effect: NoSchedule
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
```

## Практические примеры кастомизации

### Пример 1: Автоматическое создание VPS узлов при создании приложения

```yaml
# Кастомный оператор, который слушает события KuberoApp
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vps-node-manager
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: manager
        image: your-registry/vps-node-manager:latest
        env:
        - name: PROVIDER_API_KEY
          valueFrom:
            secretKeyRef:
              name: vps-provider-secret
              key: api-key
        - name: KUBERNETES_MASTER
          value: "https://kubernetes.default.svc"
```

### Пример 2: Интеграция с Hetzner Cloud API

```go
// Пример интеграции с Hetzner Cloud
package main

import (
    "github.com/hetznercloud/hcloud-go/hcloud"
)

type HetznerVPSManager struct {
    client *hcloud.Client
}

func (h *HetznerVPSManager) CreateVPSNode(region string, instanceType string) (string, error) {
    // Создать сервер
    server, _, err := h.client.Server.Create(context.Background(), hcloud.ServerCreateOpts{
        Name:       fmt.Sprintf("k8s-worker-%s", uuid.New().String()),
        ServerType: &hcloud.ServerType{Name: instanceType},
        Location:   &hcloud.Location{Name: region},
        Image:      &hcloud.Image{Name: "ubuntu-22.04"},
        SSHKeys:    []*hcloud.SSHKey{...},
        UserData:   h.generateCloudInitScript(),
    })
    
    if err != nil {
        return "", err
    }
    
    // Подождать готовности
    // Установить Kubernetes компоненты
    // Присоединить к кластеру
    
    return server.PublicNet.IPv4.IP.String(), nil
}

func (h *HetznerVPSManager) generateCloudInitScript() string {
    return `#!/bin/bash
# Установка Kubernetes компонентов
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl containerd

# Присоединение к кластеру
kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
`
}
```

### Пример 3: Масштабирование на основе метрик

```yaml
# Использование Prometheus и KEDA для автомасштабирования
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: vps-node-scaler
spec:
  scaleTargetRef:
    name: vps-node-pool
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      metricName: vps_node_cpu_usage
      threshold: '70'
      query: |
        avg(rate(container_cpu_usage_seconds_total{node_type="vps"}[5m])) * 100
```

## Ограничения и соображения

### Что Kubero НЕ делает из коробки:

1. **Управление узлами** - Kubero не создает и не удаляет узлы автоматически
2. **Автомасштабирование узлов** - требуется внешний инструмент (Cluster Autoscaler или кастомный оператор)
3. **Интеграция с провайдерами VPS** - нет встроенной поддержки API провайдеров

### Что можно сделать через кастомизацию:

1. ✅ **Расширение CRD** - добавить кастомные поля в KuberoApp/KuberoPipeline
2. ✅ **Создание операторов** - написать свой оператор для управления узлами
3. ✅ **Webhooks** - автоматически модифицировать ресурсы при создании
4. ✅ **Интеграция с внешними системами** - API провайдеров, мониторинга, etc.
5. ✅ **Node Affinity/Taints** - использовать стандартные Kubernetes механизмы

## Рекомендуемый подход

### Вариант 1: Минимальная кастомизация (рекомендуется)

Используйте стандартные Kubernetes механизмы:

1. **Node Labels и Taints** - настройте вручную при добавлении узлов
2. **Node Affinity в KuberoApp** - используйте через UI или YAML
3. **Cluster Autoscaler** - для автомасштабирования узлов (если поддерживается провайдером)

### Вариант 2: Средняя кастомизация

Создайте простой оператор для автоматизации:

1. **VPSNode CRD** - для описания желаемого состояния узлов
2. **Простой оператор** - создает/удаляет узлы через API провайдера
3. **Интеграция с Kubero** - через Mutating Webhook добавляет nodeSelector

### Вариант 3: Полная кастомизация

Расширьте Kubero полностью:

1. **Fork Kubero** - создайте свою версию с нужными функциями
2. **Расширьте CRD** - добавьте поля для управления узлами
3. **Кастомный оператор** - интегрированный с Kubero оператором

## Заключение

**Kubero достаточно кастомизируем**, но требует дополнительной разработки для:

- ✅ Автоматического создания узлов на VPS
- ✅ Автомасштабирования узлов
- ✅ Интеграции с API провайдеров

**Рекомендация**: Начните с Варианта 1 (минимальная кастомизация), используя стандартные Kubernetes механизмы. Если потребуется больше автоматизации, переходите к Варианту 2 с созданием простого оператора.

Kubero отлично подходит для управления приложениями, но управление инфраструктурой (узлами) лучше реализовать через отдельные инструменты или кастомные операторы.

