#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_SCRIPT="${SCRIPT_DIR}/cleanup-cilium-host.sh"

echo "=== Uninstall monitoring stack ==="
helm uninstall monitoring -n monitoring 2>/dev/null || true
kubectl delete namespace monitoring --wait=false 2>/dev/null || true

echo "=== Uninstall Cilium ==="
helm uninstall cilium -n kube-system 2>/dev/null || true

echo "=== Uninstall k3s ==="
/usr/local/bin/k3s-uninstall.sh 2>/dev/null || true

echo "=== Clean up system configuration ==="
sudo rm -f /etc/modules-load.d/k8s.conf
sudo rm -f /etc/sysctl.d/k8s.conf
sudo rm -rf /etc/rancher/k3s

echo "=== Clean up Cilium host networking leftovers ==="
bash "$CLEANUP_SCRIPT" post-uninstall

echo "[OK] k3s environment cleaned up"
