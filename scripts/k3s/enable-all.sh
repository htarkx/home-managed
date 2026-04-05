#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CILIUM_VALUES="${SCRIPT_DIR}/../../values/k3s/cilium.yaml"
MONITORING_VALUES="${SCRIPT_DIR}/../../values/k3s/monitoring.yaml"

echo "=== k3s + Cilium + Monitoring Stack One-Click Deployment ==="
echo ""

# 1. Install k3s
if [ -f "${SCRIPT_DIR}/k3s-install.sh" ]; then
  bash "${SCRIPT_DIR}/k3s-install.sh"
else
  echo "Error: k3s-install.sh not found"
  exit 1
fi

echo ""
read -p "Press Enter to continue deploying Cilium..."

# 2. Deploy Cilium
bash "${SCRIPT_DIR}/cilium-deploy.sh"

echo ""
read -p "Press Enter to continue deploying monitoring stack..."

# 3. Deploy monitoring
bash "${SCRIPT_DIR}/monitoring-deploy.sh"

echo ""
echo "[OK] All deployment completed!"
echo ""
echo "Verification commands:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  cilium status"
echo ""
echo "Access services:"
echo "  Hubble UI:  cilium hubble ui"
echo "  Grafana:    kubectl port-forward -n monitoring svc/grafana 3000:80"
