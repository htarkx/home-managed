#!/usr/bin/env bash
set -euo pipefail

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

echo "[OK] k3s environment cleaned up"
