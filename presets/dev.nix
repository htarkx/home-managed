# Daily development machine: minimal + LSPs, runtimes, networking CLI, k8s clients, TUI apps,
# nix-index, VS Code integration and Claude Code. No GUI wireshark, cloud SDKs or eBPF.
{ lib, ... }:
{
  imports = [ ./minimal.nix ];

  my.editor.lsp = lib.mkDefault [
    "clangd"
    "gopls"
    "nixd"
  ];
  my.dev.enable = lib.mkDefault true;
  my.net.enable = lib.mkDefault true;
  my.k8s.enable = lib.mkDefault true;
  my.tui.enable = lib.mkDefault true;
  my.nixIndex.enable = lib.mkDefault true;
  my.vscode.enable = lib.mkDefault true;
  my.claude.enable = lib.mkDefault true;
}
