# Linux performance tooling and benchmark shortcuts.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.my.perf;
in
{
  options.my.perf.enable = lib.mkEnableOption "Linux perf/benchmark tools";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "my.perf is Linux-only";
      }
    ];

    home.packages = with pkgs; [
      sysbench
      fio
      dool
      sysstat
      atop
      nmon
      iotop
      ioping
    ];

    home.shellAliases = {
      bench-cpu = "sysbench cpu --threads=$(nproc) --time=60 run";
      bench-mem = "sysbench memory --memory-total-size=20G run";
      bench-disk = "fio --name=randrw --filename=/tmp/fio.test --size=4G --bs=4k --rw=randrw --iodepth=32 --numjobs=4 --runtime=60 --time_based --group_reporting";
      bench-steal = "mpstat -P ALL 1 30";
      bench-net-server = "iperf3 -s";
    };
  };
}
