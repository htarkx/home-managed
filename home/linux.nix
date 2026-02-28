{
  pkgs,
  lib,
  config,
  ...
}:
let
  vscodeServerSettings = {
    "terminal.integrated.defaultProfile.linux" = "zsh";
    "terminal.integrated.profiles.linux" = {
      zsh = {
        path = "${config.home.homeDirectory}/.nix-profile/bin/zsh";
        args = [ "-l" ];
      };
    };
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = "nixd";
  };

  vscodeServerExtensions = [
    "eamodio.gitlens"
    "golang.go"
    "gruntfuggly.todo-tree"
    "jnoortheen.nix-ide"
    "llvm-vs-code-extensions.vscode-clangd"
    "mkhl.direnv"
    "ms-vscode.cmake-tools"
    "ms-vscode.cpp-devtools"
    "openai.chatgpt"
    "tamasfe.even-better-toml"
    "vadimcn.vscode-lldb"
  ];
in
{
  targets.genericLinux.enable = true;

  # VS Code integrated terminal often starts an interactive *non-login* zsh, which does not read ~/.zprofile.
  # Ensure Home Manager session vars (and thus nix.sh) are loaded in that case.
  programs.zsh.initContent = lib.mkBefore ''
    # --- Fix for VS Code Remote & Nix Environment (interactive shells) ---
    [[ -r ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]] && . ~/.nix-profile/etc/profile.d/hm-session-vars.sh
    export BCC_KERNEL_SOURCE="/lib/modules/$(uname -r)/build"
    # --------------------------------------------------------------------

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

  # Some environments (notably VS Code Remote) propagate __HM_SESS_VARS_SOURCED=1 but overwrite PATH/NIX_PROFILES.
  # In that case hm-session-vars.sh becomes a no-op, so we force a re-source when NIX env is missing.
  programs.zsh.envExtra = lib.mkAfter ''
    if [[ -z "$NIX_PROFILES" || ":$PATH:" != *":$HOME/.nix-profile/bin:"* ]]; then
      unset __HM_SESS_VARS_SOURCED
      [[ -r "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]] && . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    fi
  '';

  # For login shells, keep ~/.zprofile sourcing /etc/profile and ~/.profile.
  programs.zsh.profileExtra = ''
    # --- Fix for VS Code Remote & Nix Environment (login shells) ---
    [[ -r /etc/profile ]] && emulate sh -c '. /etc/profile'
    [[ -r ~/.profile ]] && emulate sh -c '. ~/.profile'
    # --------------------------------------------------------------
  '';

  home.activation.installVscodeServerExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.vscode-server/bin" ]; then
      exit 0
    fi

    code_server_bin="$(find "$HOME/.vscode-server/bin" -maxdepth 3 -type f -name code-server | head -n 1)"
    if [ -z "$code_server_bin" ]; then
      exit 0
    fi

    installed="$("$code_server_bin" --list-extensions 2>/dev/null || true)"
    while IFS= read -r ext; do
      [ -n "$ext" ] || continue
      echo "$installed" | grep -Fxiq "$ext" && continue
      "$code_server_bin" --install-extension "$ext" >/dev/null 2>&1 || true
    done <<< "${lib.concatStringsSep "\n" vscodeServerExtensions}"
  '';

  home.file.".vscode-server/data/Machine/settings.json" = {
    force = true;
    text = builtins.toJSON vscodeServerSettings;
  };

  home.packages = lib.mkAfter (
    with pkgs;
    [
      iproute2
      ethtool
      bridge-utils
      sysbench
      fio
      dool
      sysstat
      atop
      nmon
      iotop
      ioping
      bpftrace
      bcc
      bpftools
      bpfmon
    ]
  );

  home.sessionVariables = {
    BCC_TOOLS_PATH = "${pkgs.bcc}/share/bcc/tools";
  };

  home.shellAliases = {
    bench-cpu = "sysbench cpu --threads=$(nproc) --time=60 run";
    bench-mem = "sysbench memory --memory-total-size=20G run";
    bench-disk = "fio --name=randrw --filename=/tmp/fio.test --size=4G --bs=4k --rw=randrw --iodepth=32 --numjobs=4 --runtime=60 --time_based --group_reporting";
    bench-steal = "mpstat -P ALL 1 30";
    bench-net-server = "iperf3 -s";
    bcc-tools = "ls -1 ${pkgs.bcc}/share/bcc/tools";
    runqlat = "sudo env \"PATH=$PATH\" BCC_KERNEL_SOURCE=\"/lib/modules/$(uname -r)/build\" ${pkgs.bcc}/share/bcc/tools/runqlat";
    softirqs = "sudo env \"PATH=$PATH\" BCC_KERNEL_SOURCE=\"/lib/modules/$(uname -r)/build\" ${pkgs.bcc}/share/bcc/tools/softirqs";
    oomkill = "sudo env \"PATH=$PATH\" BCC_KERNEL_SOURCE=\"/lib/modules/$(uname -r)/build\" ${pkgs.bcc}/share/bcc/tools/oomkill";
    bcc-ksrc = "echo /lib/modules/$(uname -r)/build";
  };

}
