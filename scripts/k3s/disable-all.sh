#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_SCRIPT="${SCRIPT_DIR}/cleanup-cilium-host.sh"

echo "=== Disable monitoring stack ==="
helm uninstall monitoring -n monitoring 2>/dev/null || true
kubectl delete namespace monitoring --wait=false 2>/dev/null || true

echo "=== Disable Cilium ==="
helm uninstall cilium -n kube-system 2>/dev/null || true

echo "=== Disable k3s ==="
sudo systemctl stop k3s 2>/dev/null || true
sudo systemctl disable k3s 2>/dev/null || true
/usr/local/bin/k3s-uninstall.sh 2>/dev/null || true

echo "=== Remove k3s systemd leftovers ==="
sudo rm -f /etc/systemd/system/k3s.service
sudo rm -f /etc/systemd/system/k3s.service.env
sudo systemctl daemon-reload

echo "=== Clean up host configuration ==="
sudo rm -f /etc/modules-load.d/k8s.conf
sudo rm -f /etc/sysctl.d/k8s.conf
sudo rm -rf /etc/rancher/k3s

echo "=== Clean up Cilium host networking leftovers ==="
bash "$CLEANUP_SCRIPT" post-uninstall

echo "=== Clean up local kubeconfig ==="
rm -f "$HOME/.kube/config"

echo "[OK] k3s stack disabled and local state cleaned up"
