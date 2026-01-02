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

  home.activation.installVscodeServerExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    code_server_bin="$(ls -1dt "$HOME"/.vscode-server/cli/servers/Stable-*/server/bin/code-server 2>/dev/null | head -n 1)"
    if [ -z "$code_server_bin" ]; then
      code_server_bin="$(ls -1dt "$HOME"/.vscode-server/bin/*/bin/code-server 2>/dev/null | head -n 1)"
    fi

    if [ -z "$code_server_bin" ]; then
      echo "installVscodeServerExtensions: code-server not found under ~/.vscode-server" >&2
      exit 1
    fi

    installed="$("$code_server_bin" --list-extensions 2>/dev/null)"
    while IFS= read -r ext; do
      [ -n "$ext" ] || continue
      echo "$installed" | grep -Fxiq "$ext" && continue
      "$code_server_bin" --install-extension "$ext" >/dev/null 2>&1
    done <<< "${lib.concatStringsSep "\n" vscodeServerExtensions}"
  '';

  home.activation.writeVscodeServerSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_dir="$HOME/.vscode-server/data/Machine"
    settings_file="$settings_dir/settings.json"
    mkdir -p "$settings_dir"
    printf '%s\n' ${lib.escapeShellArg (builtins.toJSON vscodeServerSettings)} > "$settings_file"
  '';

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
