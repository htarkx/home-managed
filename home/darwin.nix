{ pkgs, lib, ... }:
{
  home.file."Library/Application Support/Code/User/settings.json".source = ../dotfiles/vscode/settings.darwin.json;

  home.packages = lib.mkAfter (with pkgs; [
    gnuplot
    nicotine-plus
  ]);
}
