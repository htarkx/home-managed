# eBPF tracing. Heavy: bpftrace and bcc share ~1.4 GiB of LLVM/clang runtime libraries.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.my.ebpf;
  bccTool =
    name:
    "sudo env \"PATH=$PATH\" BCC_KERNEL_SOURCE=\"/lib/modules/$(uname -r)/build\" ${pkgs.bcc}/share/bcc/tools/${name}";
in
{
  options.my.ebpf.enable = lib.mkEnableOption "eBPF tracing tools (bpftrace/bcc, ~1.7 GiB)";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "my.ebpf is Linux-only";
      }
    ];

    home.packages = with pkgs; [
      bpftrace
      bcc
      bpftools
      bpfmon
    ];

    home.sessionVariables.BCC_TOOLS_PATH = "${pkgs.bcc}/share/bcc/tools";

    home.shellAliases = {
      bcc-tools = "ls -1 ${pkgs.bcc}/share/bcc/tools";
      runqlat = bccTool "runqlat";
      softirqs = bccTool "softirqs";
      oomkill = bccTool "oomkill";
      bcc-ksrc = "echo /lib/modules/$(uname -r)/build";
    };
  };
}
