#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_PATH="${SCRIPT_DIR}/../../values/k3s/cilium.yaml"

if [ ! -f "$VALUES_PATH" ]; then
  echo "Error: Config file not found: $VALUES_PATH"
  exit 1
fi

echo "=== Add Cilium Helm repo ==="
helm repo add cilium https://helm.cilium.io/
helm repo update

echo "=== Deploy Cilium (full features) ==="
helm upgrade --install cilium cilium/cilium \
  --version 1.16.0 \
  --namespace kube-system \
  --values "$VALUES_PATH"

echo "=== Wait for Cilium to be ready ==="
if command -v cilium >/dev/null 2>&1; then
  cilium status --wait
else
  echo "cilium CLI not found in PATH, falling back to kubectl rollout checks"
  kubectl rollout status daemonset/cilium -n kube-system --timeout=10m
  kubectl rollout status daemonset/cilium-envoy -n kube-system --timeout=10m
  kubectl rollout status deployment/cilium-operator -n kube-system --timeout=10m
  kubectl rollout status deployment/hubble-relay -n kube-system --timeout=10m
  kubectl rollout status deployment/hubble-ui -n kube-system --timeout=10m
fi

echo "[OK] Cilium installation completed"
echo "  Status check:   kubectl get pods -n kube-system"
echo "                  cilium status"
echo "  Connectivity:   cilium connectivity test"
