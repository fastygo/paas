#!/bin/bash
# Скрипт для проверки интеграции VPS node с облачным кластером

set -e

VPS_NODE_NAME=${1:-"vps-worker-1"}
NAMESPACE=${2:-"paas-tenant-1"}

echo "=== Verifying VPS node integration ==="
echo "VPS Node: $VPS_NODE_NAME"
echo "Namespace: $NAMESPACE"
echo ""

# Проверка статуса узла
echo "=== Checking node status ==="
kubectl get nodes $VPS_NODE_NAME -o wide
echo ""

# Проверка labels
echo "=== Checking node labels ==="
kubectl get node $VPS_NODE_NAME --show-labels
echo ""

# Проверка taints
echo "=== Checking node taints ==="
kubectl describe node $VPS_NODE_NAME | grep -A 5 Taints || echo "No taints found"
echo ""

# Проверка StorageClass
echo "=== Checking StorageClass ==="
kubectl get storageclass | grep -E "local-storage-vps|NAME"
echo ""

# Проверка сетевой связности
echo "=== Checking network connectivity ==="
echo "Testing DNS resolution..."
kubectl run dns-test-$(date +%s) --image=busybox --rm -i --restart=Never --overrides='
{
  "spec": {
    "nodeSelector": {
      "node-type": "vps"
    }
  }
}' -- nslookup kubernetes.default.svc.cluster.local || echo "DNS test failed"
echo ""

# Проверка подов на VPS node
echo "=== Checking pods on VPS node ==="
kubectl get pods -n $NAMESPACE -o wide --field-selector spec.nodeName=$VPS_NODE_NAME
echo ""

# Проверка ресурсов узла
echo "=== Checking node resources ==="
kubectl top node $VPS_NODE_NAME 2>/dev/null || echo "Metrics server not available"
echo ""

# Проверка событий узла
echo "=== Recent node events ==="
kubectl get events --field-selector involvedObject.name=$VPS_NODE_NAME --sort-by='.lastTimestamp' | tail -10
echo ""

# Проверка CNI плагина
echo "=== Checking CNI plugin ==="
kubectl get pods -n kube-system | grep -E 'calico|flannel|cilium|weave|canal' || echo "CNI plugin pods not found"
echo ""

# Проверка сетевых политик
echo "=== Checking NetworkPolicies ==="
kubectl get networkpolicies -n $NAMESPACE || echo "No NetworkPolicies found"
echo ""

# Тест развертывания приложения
echo "=== Testing application deployment ==="
TEST_POD_NAME="test-app-$(date +%s)"
kubectl run $TEST_POD_NAME \
  --image=nginx:alpine \
  --namespace=$NAMESPACE \
  --overrides='
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
}' || echo "Failed to create test pod"

sleep 5

if kubectl get pod $TEST_POD_NAME -n $NAMESPACE &>/dev/null; then
    POD_NODE=$(kubectl get pod $TEST_POD_NAME -n $NAMESPACE -o jsonpath='{.spec.nodeName}')
    POD_STATUS=$(kubectl get pod $TEST_POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}')
    echo "Test pod created: $TEST_POD_NAME"
    echo "Pod node: $POD_NODE"
    echo "Pod status: $POD_STATUS"
    
    if [ "$POD_NODE" == "$VPS_NODE_NAME" ] && [ "$POD_STATUS" == "Running" ]; then
        echo "✓ Test pod successfully scheduled on VPS node"
    else
        echo "✗ Test pod not on VPS node or not running"
    fi
    
    # Очистка
    kubectl delete pod $TEST_POD_NAME -n $NAMESPACE
else
    echo "✗ Failed to create test pod"
fi

echo ""
echo "=== Integration verification complete ==="

