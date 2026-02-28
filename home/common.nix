{
  pkgs,
  lib,
  config,
  ...
}:
{
  programs.home-manager.enable = true;

  home.shellAliases = {
    # Base muscle memory
    ls = "eza";
    ll = "eza -lah --group-directories-first";
    cat = "bat";
    grep = "rg";
    find = "fd";

    # Observability
    top = "btop";
    df = "duf";
    du = "dust";
    f = "fastfetch";

    # Git workflow
    g = "git";
    gs = "git status -sb";
    gd = "git diff";
    gl = "git log --oneline --graph --decorate";
    lg = "lazygit";
    gui = "gitui";

    # Networking quick checks
    myip = "curl -fsSL ifconfig.me | sed 's/%.*$//'";
    myip4 = "curl -4 -fsSL ifconfig.me | sed 's/%.*$//'";
    myip6 = "curl -6 -fsSL ifconfig.me | sed 's/%.*$//'";
    digg = "dig +short";

    # Micromamba (avoid aliasing `mamba` to prevent conflicts)
    mm = "micromamba";
    mma = "micromamba activate";
    mmd = "micromamba deactivate";
    mml = "micromamba env list";
  };

  home.activation.removeBrokenNvimConfigLink = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    if [ -L "$HOME/.config/nvim" ] && [ ! -e "$HOME/.config/nvim" ]; then
      rm -f "$HOME/.config/nvim"
    fi
  '';

  home.activation.ensureNpmPrefix = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    mkdir -p "$HOME/.local/share/npm-global/bin"
  '';

  home.activation.ensureMambaRootPrefix = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    mkdir -p "$HOME/.mamba"
    mkdir -p "$HOME/.config/mamba"
  '';

  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    clock24 = true;
    baseIndex = 1;
    keyMode = "vi";
    mouse = true;
    plugins = with pkgs.tmuxPlugins; [
      sensible
      tmux-fzf
      resurrect
      continuum
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor 'mocha'
          set -g @catppuccin_window_tabs_enabled on
          set -g @catppuccin_date_time "%H:%M"
          set -g @catppuccin_status_modules_right "directory session date_time"
          set -g @catppuccin_status_left_separator "█"
          set -g @catppuccin_status_right_separator "█"
          set -g @catppuccin_directory_text "#{pane_current_path}"
        '';
      }
    ];
    extraConfig = ''
      bind -n C-h select-pane -L
      bind -n C-j select-pane -D
      bind -n C-k select-pane -U
      bind -n C-l select-pane -R

      set -g @resurrect-capture-pane-contents 'on'
      set -g @continuum-restore 'on'

      set -g status-position top
    '';
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    plugins = [
      {
        name = "omz-git";
        src = pkgs.oh-my-zsh;
        file = "share/oh-my-zsh/plugins/git/git.plugin.zsh";
      }
      {
        name = "omz-fzf";
        src = pkgs.oh-my-zsh;
        file = "share/oh-my-zsh/plugins/fzf/fzf.plugin.zsh";
      }
      {
        name = "omz-docker";
        src = pkgs.oh-my-zsh;
        file = "share/oh-my-zsh/plugins/docker/docker.plugin.zsh";
      }
      {
        name = "omz-kubectl";
        src = pkgs.oh-my-zsh;
        file = "share/oh-my-zsh/plugins/kubectl/kubectl.plugin.zsh";
      }
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh";
      }
      {
        name = "zsh-vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
      }
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    initContent = ''
      export ZVM_VI_INSERT_ESCAPE_BINDKEY=jk
      export ZVM_CURSOR_STYLE_ENABLED=true
      zstyle ':fzf-tab:*' fzf-flags '--color=fg:1,bg:2,hl:3,fg+:4,bg+:5,hl+:6'

      navi-widget() {
        local cmd
        cmd=$(navi --print </dev/tty) || return
        [[ -n "$cmd" ]] && LBUFFER+="$cmd"
        zle reset-prompt
      }
      zle -N navi-widget
      bindkey -M viins '^[g' navi-widget
      bindkey -M vicmd '^[g' navi-widget

      lazygit-widget() {
        lazygit
        zle reset-prompt
      }
      zle -N lazygit-widget
      bindkey -M viins '^g' lazygit-widget
      bindkey -M vicmd '^g' lazygit-widget

      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
      if command -v micromamba >/dev/null 2>&1; then
        export MAMBA_ROOT_PREFIX="$HOME/.mamba"
        eval "$(micromamba shell hook --shell zsh)"
      fi

      hms() {
        local root
        local use_auto_backup=1
        root=$(git rev-parse --show-toplevel 2>/dev/null) || {
          echo "hms: not inside a git repository" >&2
          return 1
        }
        for arg in "$@"; do
          case "$arg" in
            -b|--backup-ext)
              use_auto_backup=0
              ;;
          esac
        done

        (
          cd "$root" || exit
          if (( use_auto_backup )); then
            home-manager switch -b "backup-$(date +%Y%m%d-%H%M%S)" --flake .#current --impure "$@"
          else
            home-manager switch --flake .#current --impure "$@"
          fi
        )
      }

      hms-fast() {
        local root
        local use_auto_backup=1
        root=$(git rev-parse --show-toplevel 2>/dev/null) || {
          echo "hms-fast: not inside a git repository" >&2
          return 1
        }
        for arg in "$@"; do
          case "$arg" in
            -b|--backup-ext)
              use_auto_backup=0
              ;;
          esac
        done

        (
          cd "$root" || exit
          if (( use_auto_backup )); then
            home-manager switch -b "backup-$(date +%Y%m%d-%H%M%S)" --flake .#current --impure --no-build-output "$@"
          else
            home-manager switch --flake .#current --impure --no-build-output "$@"
          fi
        )
      }
    '';
  };

  programs.fzf.enable = true;

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      style = "compact";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  programs.bash = {
    enable = true;
    enableCompletion = true;
    package = pkgs.bashInteractive;
    bashrcExtra = ''
      export LANG=C.UTF-8
      export LC_ALL=C.UTF-8
      export LC_CTYPE=C.UTF-8
      export LC_COLLATE=C.UTF-8
      PS1='\[\e[38;5;39m\]\u@\h\[\e[0m\]:\[\e[38;5;111m\]\w\[\e[0m\]\$ '
    '';
  };

  home.sessionVariables = {
    SHELL = "${pkgs.zsh}/bin/zsh";
    LANG = "C.UTF-8";
    LC_ALL = "C.UTF-8";
    LC_CTYPE = "C.UTF-8";
    LC_COLLATE = "C.UTF-8";
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.local/share/npm-global";
    MAMBA_ROOT_PREFIX = "${config.home.homeDirectory}/.mamba";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/share/npm-global/bin"
  ];

  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.local/share/npm-global
  '';

  home.file.".config/mamba/mambarc".text = ''
    root_prefix: ${config.home.homeDirectory}/.mamba
  '';

  programs.nixvim = {
    enable = true;
  }
  // (import ../nixvim.nix { inherit pkgs; });

  home.packages = with pkgs; [
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    less
    tree
    watch
    ripgrep
    fd
    bat
    eza
    dust
    ncdu
    duf
    git-open
    btop
    glances
    fastfetch
    inetutils
    gitui
    lazygit
    navi
    tealdeer
    zellij
    pueue
    trippy
    tcpdump
    wireshark
    iperf3
    mtr
    nmap
    dnsutils
    curl
    wget
    httpie
    openssl
    wireguard-tools
    netcat
    socat
    nixd
    nixfmt-rfc-style
    micromamba
    nodejs_20
    yazi
    tig
  ];

  home.file.".p10k.zsh".source = ../dotfiles/.p10k.zsh;
}
