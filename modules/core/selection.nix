# Snapshot the component selection this switch applies, so `.#current` re-applies it next time
# (see lib/current.nix). Everything under `my` counts as selection except the keys below, which are
# settings rather than choices of what to install.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  notSelection = [
    "repoPath"
    "vscode"
  ];
  selection = removeAttrs config.my notSelection // {
    vscode.enable = config.my.vscode.enable;
  };
  snapshot = pkgs.writeText "home-managed-selection.json" (
    builtins.toJSON {
      version = 1; # bump with lib/current.nix when options are renamed or removed
      my = selection;
    }
  );
in
{
  home.activation.recordSelection = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.local/state/home-managed"
    run cp -f ${snapshot} "$HOME/.local/state/home-managed/selection.json"
    run chmod u+w "$HOME/.local/state/home-managed/selection.json"
  '';
}
