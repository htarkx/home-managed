# Entry point: core modules are always on; every component under ./components declares
# `my.<name>.enable` (off by default) and is switched on by a preset (presets/*.nix) or a host file
# (hosts/*.nix). The platform module (darwin/linux) is picked in flake.nix.
{
  imports = [
    ./core/base.nix
    ./core/shell.nix
    ./core/tmux.nix
    ./core/selection.nix

    ./components/editor.nix
    ./components/net.nix
    ./components/perf.nix
    ./components/ebpf.nix
    ./components/k8s.nix
    ./components/cloud.nix
    ./components/dev.nix
    ./components/tui.nix
    ./components/ops.nix
    ./components/nix-index.nix
    ./components/vscode.nix
    ./components/claude.nix
  ];
}
