# Everything, matching the pre-component setup (man pages, all treesitter grammars, wireshark GUI,
# yazi with previews, cloud SDKs, and on Linux GPU drivers, perf, eBPF, ops too).
{ lib, pkgs, ... }:
let
  linux = pkgs.stdenv.isLinux;
in
{
  imports = [ ./dev.nix ];

  my.docs.enable = lib.mkDefault true;
  my.gpu.enable = lib.mkDefault linux;
  my.editor.grammars = lib.mkDefault null;
  my.editor.providers = lib.mkDefault true;
  my.net.wireshark = lib.mkDefault "gui";
  my.tui.yaziPreviews = lib.mkDefault true;
  my.cloud.enable = lib.mkDefault true;
  my.ops.enable = lib.mkDefault true;
  my.perf.enable = lib.mkDefault linux;
  my.ebpf.enable = lib.mkDefault linux;
}
