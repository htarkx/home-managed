# Extra terminal apps. yazi's full build pulls ffmpeg/imagemagick/poppler for previews (~1 GiB);
# the default is yazi-unwrapped, which falls back gracefully when those tools are missing.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.my.tui;
in
{
  options.my.tui = {
    enable = lib.mkEnableOption "extra TUI apps (yazi, zellij, navi, glances, ...)";
    yaziPreviews = lib.mkEnableOption "yazi with all preview helpers (ffmpeg, imagemagick, poppler, ...)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      glances
      fastfetch
      gitui
      navi
      tealdeer
      zellij
      pueue
      (if cfg.yaziPreviews then yazi else yazi-unwrapped)
      tig
    ];

    home.shellAliases = {
      f = "fastfetch";
      gui = "gitui";
    };

    programs.zsh.initContent = ''
      navi-widget() {
        local cmd
        cmd=$(navi --print </dev/tty) || return
        [[ -n "$cmd" ]] && LBUFFER+="$cmd"
        zle reset-prompt
      }
      zle -N navi-widget
      bindkey -M viins '^[g' navi-widget
      bindkey -M vicmd '^[g' navi-widget
    '';
  };
}
