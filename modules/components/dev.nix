# Language runtimes and Nix tooling: Node (global npm prefix in ~/.local), micromamba, nixd, nixfmt.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.my.dev;
  home = config.home.homeDirectory;
in
{
  options.my.dev.enable = lib.mkEnableOption "dev runtimes (node, micromamba, nixd, nixfmt)";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      nixd
      nixfmt-rfc-style
      micromamba
      nodejs_20
    ];

    home.shellAliases = {
      # Micromamba (avoid aliasing `mamba` to prevent conflicts)
      mm = "micromamba";
      mma = "micromamba activate";
      mmd = "micromamba deactivate";
      mml = "micromamba env list";
    };

    home.sessionVariables = {
      NPM_CONFIG_PREFIX = "${home}/.local/share/npm-global";
      MAMBA_ROOT_PREFIX = "${home}/.mamba";
    };

    home.sessionPath = [ "${home}/.local/share/npm-global/bin" ];

    home.file.".npmrc".text = ''
      prefix=${home}/.local/share/npm-global
    '';

    home.file.".config/mamba/mambarc".text = ''
      root_prefix: ${home}/.mamba
    '';

    home.activation.ensureNpmPrefix = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      mkdir -p "$HOME/.local/share/npm-global/bin"
    '';

    home.activation.ensureMambaRootPrefix = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      mkdir -p "$HOME/.mamba"
      mkdir -p "$HOME/.config/mamba"
    '';

    programs.zsh.initContent = ''
      if command -v micromamba >/dev/null 2>&1; then
        export MAMBA_ROOT_PREFIX="$HOME/.mamba"
        eval "$(micromamba shell hook --shell zsh)"
      fi
    '';
  };
}
