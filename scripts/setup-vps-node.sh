#!/bin/bash
# Скрипт для автоматизации настройки VPS как worker node
# Использование: ./setup-vps-node.sh <MASTER_IP> <TOKEN> <CA_HASH>

set -e

MASTER_IP=${1:-""}
TOKEN=${2:-""}
CA_HASH=${3:-""}
NODE_NAME=${4:-"vps-worker-1"}
VPS_IP=${5:-""}

if [ -z "$MASTER_IP" ] || [ -z "$TOKEN" ] || [ -z "$CA_HASH" ]; then
    echo "Usage: $0 <MASTER_IP> <TOKEN> <CA_HASH> [NODE_NAME] [VPS_IP]"
    echo "Example: $0 10.0.0.1 abcdef.1234567890abcdef sha256:1234... vps-worker-1 10.0.1.100"
    exit 1
fi

echo "=== Setting up VPS as Kubernetes worker node ==="
echo "Master IP: $MASTER_IP"
echo "Node Name: $NODE_NAME"
echo "VPS IP: ${VPS_IP:-auto-detect}"

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Обновление системы
echo "=== Updating system ==="
apt-get update
apt-get upgrade -y

# Установка необходимых пакетов
echo "=== Installing required packages ==="
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Добавление репозитория Kubernetes
echo "=== Adding Kubernetes repository ==="
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

# Установка Kubernetes компонентов
echo "=== Installing Kubernetes components ==="
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Установка и настройка containerd
echo "=== Installing containerd ==="
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Настройка сетевых параметров
echo "=== Configuring network parameters ==="
modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Отключение swap
echo "=== Disabling swap ==="
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Присоединение к кластеру
echo "=== Joining Kubernetes cluster ==="
JOIN_CMD="kubeadm join $MASTER_IP:6443 --token $TOKEN --discovery-token-ca-cert-hash $CA_HASH --node-name $NODE_NAME"

if [ -n "$VPS_IP" ]; then
    JOIN_CMD="$JOIN_CMD --node-ip $VPS_IP"
fi

$JOIN_CMD

# Ожидание готовности узла
echo "=== Waiting for node to be ready ==="
sleep 10

# Настройка labels (требует kubectl с доступом к кластеру)
echo "=== Node setup complete ==="
echo ""
echo "Next steps:"
echo "1. From a machine with kubectl access to the cluster, run:"
echo "   kubectl label node $NODE_NAME node-type=vps paas-tier=tenant storage-type=local"
echo ""
echo "2. Add taint to isolate workloads:"
echo "   kubectl taint node $NODE_NAME paas-tier=tenant:NoSchedule"
echo ""
echo "3. Verify node status:"
echo "   kubectl get nodes"
echo "   kubectl describe node $NODE_NAME"

