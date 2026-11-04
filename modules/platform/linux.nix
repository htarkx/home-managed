# Linux-only base: generic-Linux integration, iproute2 & friends, VS Code Server terminal profile.
# Optional Linux tooling lives in components (perf, ebpf, k8s, ops).
{
  pkgs,
  lib,
  config,
  ...
}:
{
  targets.genericLinux = {
    enable = true;
    gpu.enable = config.my.gpu.enable;
  };

  # VS Code server machine settings (~/.vscode-server/data/Machine/settings.json, see
  # components/vscode.nix); only written when my.vscode.enable is set.
  my.vscode.settings = {
    "terminal.integrated.defaultProfile.linux" = "zsh";
    "terminal.integrated.profiles.linux" = {
      zsh = {
        path = "${config.home.homeDirectory}/.nix-profile/bin/zsh";
        args = [ "-l" ];
      };
    };
  };

  programs.zsh.initContent = lib.mkBefore ''
    ports() {
      if ! command -v ss >/dev/null 2>&1; then
        echo "ports: 'ss' not found (install iproute2)" >&2
        return 127
      fi

      if (( EUID != 0 )) && command -v sudo >/dev/null 2>&1; then
        if command sudo ss -tulpen; then
          return 0
        fi
        echo "ports: sudo failed; running ss without sudo" >&2
      fi

      command ss -tulpen
    }
  '';

  home.packages = lib.mkAfter (
    with pkgs;
    [
      iproute2
      ethtool
      bridge-utils
    ]
  );
}
