#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_PATH="${SCRIPT_DIR}/../../values/k3s/cilium.yaml"
CLEANUP_SCRIPT="${SCRIPT_DIR}/cleanup-cilium-host.sh"

if [ ! -f "$VALUES_PATH" ]; then
  echo "Error: Config file not found: $VALUES_PATH"
  exit 1
fi

if [ ! -x "$CLEANUP_SCRIPT" ]; then
  echo "Error: Cleanup script not found or not executable: $CLEANUP_SCRIPT"
  exit 1
fi

echo "=== Preflight cleanup for stale Cilium host state ==="
bash "$CLEANUP_SCRIPT" preflight

echo "=== Add Cilium Helm repo ==="
helm repo add cilium https://helm.cilium.io/
helm repo update

echo "=== Deploy Cilium (full features) ==="
helm upgrade --install cilium cilium/cilium \
  --version 1.19.3 \
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

echo "=== Validate Cilium datapath health ==="
if kubectl -n kube-system exec ds/cilium -- cilium-dbg status --verbose 2>/dev/null | grep -q "job-iptables-reconciliation-loop.*DEGRADED"; then
  echo "Error: Cilium iptables reconciliation is degraded after deployment"
  echo "Hint: inspect with: kubectl -n kube-system logs ds/cilium | grep -i reconciliation"
  exit 1
fi

echo "[OK] Cilium installation completed"
echo "  Status check:   kubectl get pods -n kube-system"
echo "                  cilium status"
echo "  Connectivity:   cilium connectivity test"
