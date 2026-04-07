#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_PATH="${SCRIPT_DIR}/../../values/k3s/monitoring.yaml"
CILIUM_VALUES_PATH="${SCRIPT_DIR}/../../values/k3s/cilium.yaml"

if [ ! -f "$VALUES_PATH" ]; then
  echo "Error: Config file not found: $VALUES_PATH"
  exit 1
fi

if [ ! -f "$CILIUM_VALUES_PATH" ]; then
  echo "Error: Config file not found: $CILIUM_VALUES_PATH"
  exit 1
fi

if ! helm status cilium -n kube-system >/dev/null 2>&1; then
  echo "Error: Cilium is not installed. Run scripts/k3s/cilium-deploy.sh first."
  exit 1
fi

echo "=== Wait for cluster node to become Ready ==="
kubectl wait --for=condition=Ready node --all --timeout=300s

echo "=== Add Prometheus repo ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "=== Bootstrap Grafana Authentik OAuth ==="
bash "${SCRIPT_DIR}/bootstrap-authentik-grafana-oauth.sh"

echo "=== Ensure monitoring namespace policy labels ==="
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace monitoring \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite

existing_status="$(helm status monitoring -n monitoring -o json 2>/dev/null | jq -r '.info.status' || true)"
if [ "$existing_status" = "pending-install" ] || [ "$existing_status" = "failed" ]; then
  echo "=== Remove unfinished monitoring release ==="
  helm uninstall monitoring -n monitoring || true
fi

echo "=== Deploy monitoring stack ==="
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values "$VALUES_PATH"

echo "=== Wait for monitoring components to be ready ==="
kubectl rollout status deployment/monitoring-kube-prometheus-operator -n monitoring --timeout=10m
kubectl rollout status deployment/monitoring-kube-state-metrics -n monitoring --timeout=10m
kubectl rollout status deployment/monitoring-grafana -n monitoring --timeout=10m
kubectl rollout status daemonset/monitoring-prometheus-node-exporter -n monitoring --timeout=10m
kubectl rollout status statefulset/alertmanager-monitoring-kube-prometheus-alertmanager -n monitoring --timeout=10m
kubectl rollout status statefulset/prometheus-monitoring-kube-prometheus-prometheus -n monitoring --timeout=10m

echo "=== Deploy Cilium monitoring ==="
helm upgrade cilium cilium/cilium \
  --version 1.16.0 \
  --namespace kube-system \
  --values "$CILIUM_VALUES_PATH" \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true

echo "[OK] Monitoring stack installation completed"
echo "  Grafana password: kubectl get secret -n monitoring grafana -o jsonpath='{.data.admin-password}' | base64 -d"
echo "  Port forward:     kubectl port-forward -n monitoring svc/grafana 3000:80"
