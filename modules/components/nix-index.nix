# nix-index with the prebuilt database, plus `,` (comma) to run any nixpkgs binary ad hoc.
{ lib, config, ... }:
let
  enabled = config.my.nixIndex.enable;
in
{
  options.my.nixIndex.enable = lib.mkEnableOption "nix-index database + comma";

  config = lib.mkMerge [
    # The nix-index-database module links its database into ~/.cache/nix-index whether or not
    # nix-index is enabled; tie that link to this component.
    { programs.nix-index.symlinkToCacheHome = lib.mkDefault enabled; }
    (lib.mkIf enabled {
      programs.nix-index.enable = true;
      programs.nix-index-database.comma.enable = true;
    })
  ];
}
