# Disk health and backups.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.my.ops;
in
{
  options.my.ops.enable = lib.mkEnableOption "smartmontools + borgbackup (Linux)";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.smartmontools ] ++ lib.optional pkgs.stdenv.isLinux pkgs.borgbackup.out;
  };
}
