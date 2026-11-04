# Always installed: zsh + plugins, bash fallback, fzf / zoxide / atuin / direnv, and the `hms` helpers.
{
  pkgs,
  lib,
  config,
  ...
}:
{
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

    initContent = lib.mkMerge [
      # 直接 source omz 插件（未走 oh-my-zsh.sh），需在插件加载前
      # 手动设置 ZSH_CACHE_DIR 并创建 completions 目录，
      # 否则 docker 等插件会报 `tee: /completions/_docker: No such file or directory`
      (lib.mkBefore ''
        export ZSH_CACHE_DIR="$HOME/.cache/oh-my-zsh"
        mkdir -p "$ZSH_CACHE_DIR/completions"
      '')
      ''
        # Re-source the Nix daemon profile. macOS system updates periodically
        # rewrite /etc/zshrc back to the vendor version, dropping the installer's
        # nix-daemon.sh block; that takes the whole nix toolchain and
        # ~/.nix-profile/bin off PATH. Sourcing here (guarded internally by
        # $__ETC_PROFILE_NIX_SOURCED, so it is a no-op when /etc/zshrc still runs
        # it) makes interactive shells self-heal after such an update.
        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
          . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
        fi

        # Re-assert user PATH for interactive shells. hm-session-vars.sh prepends
        # ~/.local/bin via a once-only guard ($__HM_SESS_VARS_SOURCED); a long-lived
        # VSCode server inherits that flag and its terminals skip the prepend.
        export PATH="$HOME/.local/bin:$HOME/.local/share/npm-global/bin:$PATH"

        # Target selection: an explicit name wins (`hms dev`); otherwise hosts/<short hostname>.nix
        # when it exists; otherwise `current` (re-applies this machine's last selection; see
        # lib/current.nix).
        hm_switch() {
          local fast_mode=0
          local config="current"
          local host_file="hosts/$(hostname -s 2>/dev/null).nix"
          [[ -f "$host_file" ]] && config="''${host_file:t:r}"
          if [[ "$1" == "--fast" ]]; then
            fast_mode=1
            shift
          fi
          local -a args=("$@")
          local i=1

          while (( i <= $# )); do
            case "''${args[i]}" in
              -b|--backup-ext)
                (( i += 2 ))
                ;;
              --backup-ext=*)
                (( i += 1 ))
                ;;
              *)
                break
                ;;
            esac
          done

          if (( i <= $# )) && [[ "''${args[i]}" != -* ]]; then
            config="''${args[i]}"
            args[i]=()
          fi

          echo "hm_switch: .#$config" >&2
          if (( fast_mode )); then
            home-manager switch --flake ".#''$config" --impure --no-build-output --option warn-dirty false "''${args[@]}"
          else
            home-manager switch --flake ".#''$config" --impure --option warn-dirty false "''${args[@]}"
          fi
        }

        export ZVM_VI_INSERT_ESCAPE_BINDKEY=jk
        export ZVM_CURSOR_STYLE_ENABLED=true
        zstyle ':fzf-tab:*' fzf-flags '--color=fg:1,bg:2,hl:3,fg+:4,bg+:5,hl+:6'

        lazygit-widget() {
          lazygit
          zle reset-prompt
        }
        zle -N lazygit-widget
        bindkey -M viins '^g' lazygit-widget
        bindkey -M vicmd '^g' lazygit-widget

        [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

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
              hm_switch -b "backup-$(date +%Y%m%d-%H%M%S)" "$@"
            else
              hm_switch "$@"
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
              hm_switch --fast -b "backup-$(date +%Y%m%d-%H%M%S)" "$@"
            else
              hm_switch --fast "$@"
            fi
          )
        }
      ''
      # zoxide 必须在所有插件之后初始化，否则会触发 doctor 警告
      # Claude Code（CLAUDECODE=1）会把 shell 函数快照复用但丢掉 chpwd_functions，
      # 导致 zoxide 的 cd 每次都报 doctor 警告；agent 里的 cd 也不该模糊跳转，故跳过
      (lib.mkAfter ''
        if [[ -z "$CLAUDECODE" ]]; then
          eval "$(${pkgs.zoxide}/bin/zoxide init zsh --cmd cd)"
        fi
      '')
    ];
  };

  programs.fzf.enable = true;

  programs.zoxide = {
    enable = true;
    # zoxide must initialize AFTER every hook-registering plugin (powerlevel10k,
    # zsh-vi-mode, zsh-syntax-highlighting); home-manager's integration evals it
    # near the top of .zshrc, so `zoxide doctor` warns it is not last. We disable
    # it here and re-init at the tail of initContent instead.
    enableZshIntegration = false;
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

  programs.bash = {
    enable = true;
    enableCompletion = true;
    package = pkgs.bashInteractive;
    bashrcExtra = ''
      # See the zsh initContent note: macOS updates rewrite /etc/{zshrc,bashrc}
      # and drop the nix-daemon.sh block, taking nix off PATH. Re-source it here
      # (guarded internally by $__ETC_PROFILE_NIX_SOURCED) so shells self-heal.
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi

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
  };

  home.sessionPath = [
    # claude code installs here; was previously not in PATH and forced
    # the post-install warning to suggest editing .zshrc manually
    # (which would be clobbered by the next home-manager switch).
    "${config.home.homeDirectory}/.local/bin"
  ];

  home.file.".p10k.zsh".source = ../../dotfiles/.p10k.zsh;
}
