# What `.#current` installs (the setup script and a bare `hms` apply it). Resolved in order:
#
#   1. recorded — the component selection the last switch on this machine applied, snapshotted by
#      modules/core/selection.nix into ~/.local/state/home-managed/selection.json. Whatever a machine
#      was switched to (a preset, a host file, `hms dev`), `current` re-applies exactly that.
#   2. inferred — Home Manager was applied here before selections were recorded: read which programs
#      the active generation has in home-path/bin and turn on the matching components, so the machine
#      keeps what it actually had (e.g. a `.#k3s` install keeps cilium, one without bpftrace stays
#      without eBPF).
#   3. fresh — nothing applied yet: the minimal preset.
#
# Needs --impure (as every target here does). In pure evaluation `home` is empty and this resolves
# to `fresh`.
{
  lib,
  home,
  user,
}:
let
  stateFile = "${home}/.local/state/home-managed/selection.json";
  schemaVersion = 1;

  recorded =
    if home != "" && builtins.pathExists stateFile then
      let
        data = builtins.fromJSON (builtins.readFile stateFile);
      in
      if (data.version or null) == schemaVersion then data.my else null
    else
      null;

  generation = lib.findFirst (p: builtins.pathExists "${p}/home-path/bin") null (
    lib.optionals (home != "") [
      "${home}/.local/state/nix/profiles/home-manager"
      "${home}/.local/state/home-manager/gcroots/current-home"
      "/nix/var/nix/profiles/per-user/${user}/home-manager"
    ]
  );

  bins = if generation == null then { } else builtins.readDir "${generation}/home-path/bin";
  has = bin: bins ? ${bin};
  any = lib.any has;

  # Pre-component installs had no knobs: every enabled tool came with its heaviest variant (all LSPs
  # and grammars, man pages, yazi previews, GPU drivers on Linux). Only which tools are present varies.
  inferred =
    { pkgs, ... }:
    {
      my = {
        editor = {
          enable = has "nvim";
          lsp = [
            "clangd"
            "gopls"
            "nixd"
          ];
          grammars = null;
          providers = true;
        };
        net = {
          enable = any [
            "nmap"
            "tcpdump"
            "mtr"
            "iperf3"
          ];
          wireshark =
            if has "wireshark" then
              "gui"
            else if has "tshark" then
              "cli"
            else
              "none";
        };
        perf.enable = has "sysbench";
        ebpf.enable = has "bpftrace";
        k8s = {
          enable = has "kubectl";
          cilium = has "cilium";
        };
        cloud = rec {
          gcloud = has "gcloud";
          ansible = has "ansible";
          kops = has "kops";
          step = has "step";
          enable = gcloud || ansible || kops || step;
        };
        dev.enable = any [
          "node"
          "micromamba"
          "nixd"
        ];
        tui = {
          enable = any [
            "yazi"
            "zellij"
            "navi"
          ];
          yaziPreviews = true;
        };
        ops.enable = any [
          "smartctl"
          "borg"
        ];
        nixIndex.enable = has "nix-locate";
        # Always part of the old setup; neither leaves a trace in home-path/bin on every version.
        vscode.enable = true;
        claude.enable = true;
        docs.enable = true;
        gpu.enable = pkgs.stdenv.isLinux;
      };
    };
in
if recorded != null then
  {
    source = "recorded selection (${stateFile})";
    module = {
      my = recorded;
    };
  }
else if generation != null then
  {
    source = "inferred from the existing Home Manager generation (${generation})";
    module = inferred;
  }
else
  {
    source = "fresh machine: minimal preset";
    module = ../presets/minimal.nix;
  }
