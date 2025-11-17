# paas-kube-article

Notes
- у helmwave есть одна проблема, проще показать на примере. В chart для envoy-gateway есть pre и post install hooks
и они всегда дают diff для установки, поэтому каждый раз будет ставится новый релиз.


kubectl port-forward svc/cyclops-ui 3000:3000 -n paas-tenant-1

kubectl get gateway/gateway -n paas-tenant-1 -o=jsonpath='{.status.addresses[0].value}'