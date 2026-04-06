#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-preflight}"

log() {
  printf '[cleanup-cilium-host] %s\n' "$1"
}

run_sudo() {
  sudo "$@"
}

flush_delete_chain() {
  local table="$1"
  local chain="$2"

  if ! run_sudo iptables -t "$table" -S "$chain" >/dev/null 2>&1; then
    return 0
  fi

  while run_sudo iptables -t "$table" -C PREROUTING -j "$chain" >/dev/null 2>&1; do
    run_sudo iptables -t "$table" -D PREROUTING -j "$chain" || true
  done
  while run_sudo iptables -t "$table" -C INPUT -j "$chain" >/dev/null 2>&1; do
    run_sudo iptables -t "$table" -D INPUT -j "$chain" || true
  done
  while run_sudo iptables -t "$table" -C OUTPUT -j "$chain" >/dev/null 2>&1; do
    run_sudo iptables -t "$table" -D OUTPUT -j "$chain" || true
  done
  while run_sudo iptables -t "$table" -C FORWARD -j "$chain" >/dev/null 2>&1; do
    run_sudo iptables -t "$table" -D FORWARD -j "$chain" || true
  done
  while run_sudo iptables -t "$table" -C POSTROUTING -j "$chain" >/dev/null 2>&1; do
    run_sudo iptables -t "$table" -D POSTROUTING -j "$chain" || true
  done

  run_sudo iptables -t "$table" -F "$chain" || true
  run_sudo iptables -t "$table" -X "$chain" || true
}

cleanup_old_cilium_chains() {
  log "Removing stale OLD_CILIUM_* iptables chains"
  local tables=(filter nat mangle raw)
  local chains=(
    OLD_CILIUM_FORWARD
    OLD_CILIUM_INPUT
    OLD_CILIUM_OUTPUT
    OLD_CILIUM_POST_nat
    OLD_CILIUM_PRE_nat
    OLD_CILIUM_OUTPUT_nat
  )

  local table
  local chain
  for table in "${tables[@]}"; do
    for chain in "${chains[@]}"; do
      flush_delete_chain "$table" "$chain"
    done
  done
}

cleanup_orphaned_links() {
  log "Removing orphaned Cilium links if they exist"
  local links=(
    cilium_host
    cilium_net
    cilium_vxlan
    lxc_health
  )

  local link
  for link in "${links[@]}"; do
    if ip link show "$link" >/dev/null 2>&1; then
      run_sudo ip link delete "$link" || true
    fi
  done
}

cleanup_orphaned_routes() {
  log "Removing orphaned Cilium routes if they exist"
  local routes
  routes="$(ip route show | grep -E 'cilium_host|cilium_net|cilium_vxlan' || true)"
  if [ -z "$routes" ]; then
    return 0
  fi

  while IFS= read -r route; do
    [ -n "$route" ] || continue
    run_sudo ip route del $route || true
  done <<<"$routes"
}

cleanup_bpffs() {
  if [ -d /sys/fs/bpf/tc/globals ]; then
    log "Cleaning stale Cilium BPF maps from /sys/fs/bpf/tc/globals"
    run_sudo find /sys/fs/bpf/tc/globals -maxdepth 1 -type f \( -name 'cilium_*' -o -name 'tunnel_map' \) -delete || true
  fi
}

preflight_cleanup() {
  cleanup_old_cilium_chains
}

post_uninstall_cleanup() {
  cleanup_old_cilium_chains
  cleanup_orphaned_routes
  cleanup_orphaned_links
  cleanup_bpffs
}

case "$MODE" in
  preflight)
    preflight_cleanup
    ;;
  post-uninstall)
    post_uninstall_cleanup
    ;;
  *)
    echo "Usage: $0 [preflight|post-uninstall]" >&2
    exit 1
    ;;
esac

log "Done"
