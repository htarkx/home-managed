# Neovim via nixvim. Lean by default: no LSP servers and a short grammar list; presets widen it.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.my.editor;
in
{
  options.my.editor = {
    enable = lib.mkEnableOption "nixvim editor";
    lsp = lib.mkOption {
      type =
        with lib.types;
        listOf (enum [
          "clangd"
          "gopls"
          "nixd"
        ]);
      default = [ ];
      description = "LSP servers to enable. clangd pulls clang-tools, gopls pulls the go toolchain.";
    };
    providers = lib.mkEnableOption ''
      neovim's Ruby and Python 3 remote-plugin providers (every configured plugin is Lua, so they are
      only needed for third-party remote plugins)'';
    grammars = lib.mkOption {
      type = with lib.types; nullOr (listOf str);
      default = [
        "bash"
        "c"
        "cpp"
        "go"
        "nix"
        "lua"
        "vim"
        "vimdoc"
        "query"
        "python"
        "json"
        "yaml"
        "toml"
        "markdown"
        "markdown_inline"
        "regex"
        "dockerfile"
        "make"
        "diff"
        "gitcommit"
      ];
      description = "Treesitter grammars to install; null installs every grammar nixpkgs builds.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.nixvim = {
      enable = true;
      enableMan = config.my.docs.enable;
      withRuby = cfg.providers;
      withPython3 = cfg.providers;
    }
    // (import ../../nixvim.nix {
      inherit pkgs;
      inherit (cfg) lsp grammars;
    });

    home.activation.removeBrokenNvimConfigLink = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      if [ -L "$HOME/.config/nvim" ] && [ ! -e "$HOME/.config/nvim" ]; then
        rm -f "$HOME/.config/nvim"
      fi
    '';
  };
}
