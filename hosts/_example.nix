# Copy to hosts/<short hostname>.nix (`hostname -s`) and commit it. Files starting with `_` are
# ignored. Each host file becomes `homeConfigurations.<name>`, and `hms` with no target picks the
# file matching the current hostname automatically.
{ lib, ... }:
{
  imports = [ ../presets/minimal.nix ]; # or ../presets/dev.nix / ../presets/full.nix

  my.net.enable = true;
  # my.net.wireshark = "gui";          # "none" | "cli" (default) | "gui"
  my.perf.enable = true; # Linux only
  # my.ebpf.enable = true;             # Linux only, ~1.7 GiB
  # my.k8s = { enable = true; cilium = true; };
  # my.cloud = { enable = true; gcloud = false; };
  # my.editor.lsp = [ "nixd" ];
  # my.repoPath = "/home/me/src/home-managed";
}
