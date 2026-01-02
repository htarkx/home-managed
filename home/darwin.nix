{ pkgs, lib, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    gnuplot
    nicotine-plus
  ]);
}
