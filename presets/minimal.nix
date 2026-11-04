# Core shell + a lean nixvim (no LSP, short grammar list). Everything else off.
{ lib, ... }:
{
  my.editor.enable = lib.mkDefault true;
}
