#!/usr/bin/env bash
set -euo pipefail

echo "=== System Optimization ==="
# Disable swap
sudo swapoff -a || true
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Kernel modules
sudo tee /etc/modules-load.d/k8s.conf >/dev/null <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay br_netfilter

# sysctl configuration
sudo tee /etc/sysctl.d/k8s.conf >/dev/null <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system >/dev/null

echo "=== Install k3s ==="
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml >/dev/null <<EOF
write-kubeconfig-mode: 0644
disable: traefik
flannel-backend: none
node-name: localhost
EOF

curl -sfL https://get.k3s.io | K3S_EXEC="--disable-network-policy" sh -

echo "=== Configure kubectl ==="
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

echo "[OK] k3s installation completed"
echo "  Node status: kubectl get nodes"
echo "  Pods:        kubectl get pods -A"
