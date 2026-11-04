# Networking diagnostics and traffic tools.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.my.net;
in
{
  options.my.net = {
    enable = lib.mkEnableOption "networking diagnostics";
    wireshark = lib.mkOption {
      type = lib.types.enum [
        "none"
        "cli"
        "gui"
      ];
      default = "cli";
      description = ''
        "cli" installs tshark/dumpcap only (~0.3 GiB closure); "gui" installs the Qt app (~1.5 GiB).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        inetutils
        trippy
        tcpdump
        iperf3
        mtr
        nexttrace
        nmap
        dnsutils
        httpie
        wireguard-tools
        netcat
        socat
      ]
      ++ lib.optional (cfg.wireshark == "cli") wireshark-cli
      ++ lib.optional (cfg.wireshark == "gui") wireshark;

    home.shellAliases = {
      nt = "sudo ${config.home.profileDirectory}/bin/nexttrace";
      digg = "dig +short";
    };
  };
}
