# Руководство по интеграции кастомного PAAS с облачным Kubernetes

## Архитектура

```
┌─────────────────────────────────────────────────────────┐
│           Облачный Kubernetes (Managed)                  │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Master Node (управляется провайдером)           │   │
│  │  - API Server                                    │   │
│  │  - etcd                                          │   │
│  │  - Controller Manager                            │   │
│  │  - Scheduler                                     │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Cloud Worker Nodes                              │   │
│  │  - Основные сервисы (IAM, Grafana, Operators)   │   │
│  │  - Envoy Gateway                                 │   │
│  │  - CloudNativePG Operator                        │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                        │
                        │ VPN / Private Network
                        │
┌─────────────────────────────────────────────────────────┐
│           VPS Worker Node (ваш кастомный PAAS)          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  - Приложения (Supabase, n8n, nocodb, etc.)      │   │
│  │  - Tenant workloads                              │   │
│  │  - Cyclops UI (tenant instances)                 │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Требования для интеграции

### 1. Сетевая связность

#### Вариант A: VPN туннель (рекомендуется)
- **WireGuard** или **OpenVPN** между облаком и VPS
- Приватная сеть для Kubernetes pod network
- Стабильное соединение с низкой латентностью

#### Вариант B: Публичный IP с firewall
- Менее безопасно
- Требует настройки firewall правил
- Возможны проблемы с NAT

### 2. Kubernetes версии
- Версия Kubernetes на VPS должна совпадать с облачным кластером
- Проверьте: `kubectl version --short`

### 3. CNI Plugin совместимость
- Убедитесь, что CNI плагин поддерживает multi-node кластеры
- Популярные: Calico, Flannel, Cilium, Weave Net

## Пошаговая инструкция

### Шаг 1: Подготовка VPS как Worker Node

#### 1.1 Установка Kubernetes компонентов

```bash
# На VPS
# Установите kubelet, kubeadm, kubectl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Установите Container Runtime (containerd)
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

#### 1.2 Настройка сетевых параметров

```bash
# На VPS
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

#### 1.3 Получение токена для присоединения к кластеру

```bash
# На облачном master node (или через kubectl с доступом к кластеру)
# Создайте токен для присоединения worker node
kubeadm token create --print-join-command

# Или создайте токен вручную
kubeadm token create --ttl 2h --description "VPS worker node token"
kubeadm token list

# Получите CA certificate hash
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
```

#### 1.4 Присоединение VPS к кластеру

```bash
# На VPS
# Используйте команду из шага 1.3, добавив параметры для вашей сети
sudo kubeadm join <MASTER_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH> \
  --node-name vps-worker-1 \
  --node-ip <VPS_PRIVATE_IP>
```

### Шаг 2: Настройка Node Labels и Taints

#### 2.1 Добавление labels для идентификации VPS node

```bash
# После присоединения к кластеру
kubectl label node vps-worker-1 \
  node-type=vps \
  paas-tier=tenant \
  storage-type=local

# Проверка
kubectl get nodes --show-labels
```

#### 2.2 Настройка Taints для изоляции workload

```bash
# Запретить запуск подов без специального toleration
kubectl taint node vps-worker-1 \
  paas-tier=tenant:NoSchedule \
  --overwrite

# Или более мягкий вариант (позволяет системным подам)
kubectl taint node vps-worker-1 \
  paas-tier=tenant:PreferNoSchedule \
  --overwrite
```

### Шаг 3: Настройка Storage Classes

#### 3.1 Создание Local Storage Class для VPS

```yaml
# local-storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage-vps
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

#### 3.2 Обновление values.yaml для использования правильного StorageClass

```yaml
# paas-system/values.yaml или paas-tenant-pg/values.yaml
pgIam:
  persistent:
    enabled: true
    storageClassName: local-storage-vps  # вместо csi-ceph-ssd-me1
```

#### 3.3 Настройка Local Volume Provisioner (опционально)

```bash
# Если нужна автоматическая подготовка локальных томов
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/sig-storage-local-static-provisioner/master/deployment/kubernetes/example/default_example_storageclass.yaml
```

### Шаг 4: Настройка Node Affinity для Pods

#### 4.1 Обновление Deployment templates для tenant workloads

```yaml
# Пример для paas-tenant/templates/cyclops-ui.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cyclops-ui
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: paas-tier
                operator: In
                values:
                - tenant
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: node-type
                operator: In
                values:
                - vps
      tolerations:
      - key: paas-tier
        operator: Equal
        value: tenant
        effect: NoSchedule
```

### Шаг 5: Настройка сетевой связности

#### 5.1 Проверка CNI плагина

```bash
# Проверьте, что CNI плагин работает между узлами
kubectl get pods -n kube-system | grep -E 'calico|flannel|cilium|weave'

# Проверьте сетевую связность между подами
kubectl run test-pod-cloud --image=busybox --rm -it --restart=Never --overrides='
{
  "spec": {
    "nodeSelector": {
      "node-type": "cloud"
    }
  }
}' -- nslookup kubernetes.default

kubectl run test-pod-vps --image=busybox --rm -it --restart=Never --overrides='
{
  "spec": {
    "nodeSelector": {
      "node-type": "vps"
    }
  }
}' -- nslookup kubernetes.default
```

#### 5.2 Настройка Firewall правил (если используется публичный IP)

```bash
# На VPS
# Разрешите трафик от облачного кластера
sudo ufw allow from <CLOUD_CLUSTER_CIDR> to any port 10250  # kubelet
sudo ufw allow from <CLOUD_CLUSTER_CIDR> to any port 10259  # kube-proxy
sudo ufw allow from <CLOUD_CLUSTER_CIDR> to any port 10250  # kubelet read-only
sudo ufw allow from <CLOUD_CLUSTER_CIDR> to any port 30000:32767  # NodePort services
```

### Шаг 6: Обновление конфигурации PAAS

#### 6.1 Создание файла для nodeSelector и tolerations

```yaml
# paas-tenant/values.yaml
nodeSelector:
  paas-tier: tenant
  node-type: vps

tolerations:
  - key: paas-tier
    operator: Equal
    value: tenant
    effect: NoSchedule

storageClass:
  default: local-storage-vps
```

#### 6.2 Обновление Helm templates для поддержки nodeSelector

```yaml
# Пример для всех Deployment в paas-tenant/templates/
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.name }}
spec:
  template:
    spec:
      {{- if .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml .Values.nodeSelector | nindent 8 }}
      {{- end }}
      {{- if .Values.tolerations }}
      tolerations:
        {{- toYaml .Values.tolerations | nindent 8 }}
      {{- end }}
```

### Шаг 7: Настройка DNS и Service Discovery

#### 7.1 Проверка CoreDNS

```bash
# Убедитесь, что CoreDNS работает на всех узлах
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Проверьте DNS разрешение между namespace
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup iam-service.paas-system.svc.cluster.local
```

#### 7.2 Настройка ExternalDNS (если нужен внешний DNS)

```yaml
# external-dns-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: external-dns-config
  namespace: kube-system
data:
  # Настройки для вашего DNS провайдера
```

### Шаг 8: Безопасность и RBAC

#### 8.1 Настройка Network Policies (опционально)

```yaml
# network-policy-tenant.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: paas-tenant-1
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: paas-system
    - namespaceSelector:
        matchLabels:
          name: paas-operators
  egress:
  - to:
    - namespaceSelector: {}
  - to:
    - namespaceSelector:
        matchLabels:
          name: paas-system
```

#### 8.2 Настройка Pod Security Standards

```yaml
# pod-security-policy.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: paas-tenant-1
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Шаг 9: Мониторинг и логирование

#### 9.1 Настройка метрик для VPS node

```bash
# Убедитесь, что node-exporter или аналогичный работает
kubectl get pods -n monitoring | grep node-exporter

# Проверьте метрики узла
kubectl top node vps-worker-1
```

#### 9.2 Настройка централизованного логирования

```yaml
# Если используете Loki или аналогичный
# Настройте сбор логов с VPS node
```

### Шаг 10: Тестирование интеграции

#### 10.1 Проверка доступности узла

```bash
# Проверьте статус узла
kubectl get nodes
kubectl describe node vps-worker-1

# Проверьте, что узел Ready
kubectl get nodes -o wide
```

#### 10.2 Развертывание тестового приложения

```bash
# Создайте тестовый pod на VPS node
kubectl run test-app --image=nginx --overrides='
{
  "spec": {
    "nodeSelector": {
      "node-type": "vps"
    },
    "tolerations": [
      {
        "key": "paas-tier",
        "operator": "Equal",
        "value": "tenant",
        "effect": "NoSchedule"
      }
    ]
  }
}' -n paas-tenant-1

# Проверьте, что pod запустился на правильном узле
kubectl get pods -n paas-tenant-1 -o wide
```

#### 10.3 Проверка сетевой связности между узлами

```bash
# Запустите pod на облачном узле
kubectl run test-cloud --image=busybox --rm -it --restart=Never --overrides='
{
  "spec": {
    "nodeSelector": {
      "node-type": "cloud"
    }
  }
}' -- sh

# Внутри пода попробуйте подключиться к сервису на VPS
# wget -O- http://test-app.paas-tenant-1.svc.cluster.local
```

## Синхронизация конфигураций

### Вариант 1: GitOps с ArgoCD или Flux

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: paas-tenant-vps
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/paas-config
    targetRevision: HEAD
    path: paas-tenant
    helm:
      valueFiles:
      - values/env.yaml
      - values/vps-override.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: paas-tenant-1
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Вариант 2: Helmwave с разными конфигурациями

```yaml
# helmwave.yml
releases:
  - name: "tenant-vps"
    namespace: "paas-tenant-1"
    chart:
      name: "./paas-tenant"
    values:
      - "values/env.yaml"
      - "values/vps-override.yaml"  # Специфичные настройки для VPS
    nodeSelector:
      node-type: vps
```

### Вариант 3: Kustomize overlays

```
base/
  paas-tenant/
    kustomization.yaml
overlays/
  vps/
    kustomization.yaml
    node-selector.yaml
    storage-class.yaml
```

## Чеклист интеграции

- [ ] VPS подключен к облачному Kubernetes кластеру как worker node
- [ ] Node labels и taints настроены
- [ ] Storage Class создан и настроен для VPS
- [ ] Сетевая связность между узлами работает
- [ ] DNS и Service Discovery работают корректно
- [ ] Node Affinity настроен для tenant workloads
- [ ] Tolerations добавлены в Deployment templates
- [ ] Firewall правила настроены (если нужно)
- [ ] Мониторинг настроен для VPS node
- [ ] Тестовые приложения успешно развернуты на VPS
- [ ] Сетевая связность между подами на разных узлах работает
- [ ] Storage работает корректно на VPS
- [ ] Логирование настроено

## Возможные проблемы и решения

### Проблема 1: Pod не запускается на VPS node

**Решение:**
```bash
# Проверьте taints и tolerations
kubectl describe node vps-worker-1 | grep Taint
kubectl describe pod <pod-name> | grep -A 5 Tolerations

# Проверьте nodeSelector
kubectl describe pod <pod-name> | grep -A 5 Node-Selectors
```

### Проблема 2: Сетевая связность между узлами не работает

**Решение:**
```bash
# Проверьте CNI плагин
kubectl get pods -n kube-system | grep -E 'calico|flannel|cilium'

# Проверьте firewall правила
sudo ufw status

# Проверьте маршруты
ip route show
```

### Проблема 3: Storage не работает

**Решение:**
```bash
# Проверьте StorageClass
kubectl get storageclass

# Проверьте PVC
kubectl get pvc -n paas-tenant-1

# Проверьте события
kubectl describe pvc <pvc-name> -n paas-tenant-1
```

### Проблема 4: Высокая латентность между узлами

**Решение:**
- Используйте VPN туннель вместо публичного IP
- Оптимизируйте сетевые маршруты
- Рассмотрите использование региональных узлов ближе к VPS

## Рекомендации по безопасности

1. **Используйте VPN** для связи между облаком и VPS
2. **Настройте Network Policies** для изоляции трафика
3. **Используйте TLS** для всех соединений между компонентами
4. **Ограничьте RBAC** права для tenant namespace
5. **Регулярно обновляйте** Kubernetes и компоненты
6. **Мониторьте** сетевую активность между узлами
7. **Используйте Pod Security Standards** для ограничения привилегий

## Дополнительные ресурсы

- [Kubernetes Multi-Node Cluster Setup](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [Node Affinity and Taints/Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

