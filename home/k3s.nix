{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.k3s.enable = lib.mkEnableOption "k3s Cilium tools";

  config = lib.mkIf config.k3s.enable {
    home.packages = with pkgs; [
      cilium-cli
    ];
  };
}
