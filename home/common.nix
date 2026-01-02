{ pkgs, lib, config, ... }:
{
  programs.home-manager.enable = true;

  home.activation.removeBrokenNvimConfigLink = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    if [ -L "$HOME/.config/nvim" ] && [ ! -e "$HOME/.config/nvim" ]; then
      rm -f "$HOME/.config/nvim"
    fi
  '';

  home.activation.ensureNpmPrefix = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    mkdir -p "$HOME/.local/share/npm-global/bin"
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
    ];
    extraConfig = ''
      bind -n C-h select-pane -L
      bind -n C-j select-pane -D
      bind -n C-k select-pane -U
      bind -n C-l select-pane -R

      set -g status on
      set -g status-position top
      set -g status-interval 5
      set -g status-justify left
      set -g status-left-length 40
      set -g status-right-length 120
      set -g status-style "bg=colour235,fg=colour248"
      set -g window-status-style "fg=colour244,bg=colour235"
      set -g window-status-current-style "fg=colour231,bg=colour31"
      set -g status-left "#[bold] #S #[default] "
      setw -g window-status-format " #I:#W "
      setw -g window-status-current-format " #[bold]#I:#W#[default] "
      set -g status-right "\
#[fg=colour244]#H \
#[fg=colour244]%Y-%m-%d \
#[fg=colour248]%H:%M \
"
    '';
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
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

      # Networking quick checks
      myip = "curl -fsSL ifconfig.me";
      digg = "dig +short";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "z"
        "fzf"
        "docker"
        "kubectl"
        "history-substring-search"
      ];
    };

    plugins = [
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh";
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
      bindkey -v
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
      if command -v micromamba >/dev/null 2>&1; then
        eval "$(micromamba shell hook --shell zsh)"
      fi

      hms() {
        local root
        root=$(git rev-parse --show-toplevel 2>/dev/null) || {
          echo "hms: not inside a git repository" >&2
          return 1
        }

        (
          cd "$root" || exit
          home-manager switch --flake .#current --impure "$@"
        )
      }

      hms-fast() {
        local root
        root=$(git rev-parse --show-toplevel 2>/dev/null) || {
          echo "hms-fast: not inside a git repository" >&2
          return 1
        }

        (
          cd "$root" || exit
          home-manager switch --flake .#current --impure --no-build-output "$@"
        )
      }
    '';
  };

  programs.fzf.enable = true;

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
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/share/npm-global/bin"
  ];

  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.local/share/npm-global
  '';

  programs.nixvim =
    { enable = true; }
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
    fastfetch
    inetutils
    lazygit
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
    netcat
    socat
    micromamba
    nodejs_20
  ];

  home.file.".p10k.zsh".source = ../dotfiles/.p10k.zsh;
}
