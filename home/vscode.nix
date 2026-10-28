# VS Code user settings with one source of truth.
#
# Modules declare keys under `my.vscode.settings` (shared ones in common.nix, OS-specific ones in
# darwin.nix / linux.nix). The module system merges them and rejects one key with two different values,
# so every setting has exactly one place where it is defined.
#
# On activation the declared keys are merged into the real settings.json with jq: declared keys win,
# keys written by VS Code, extensions or the settings UI are kept. The file stays a normal writable
# file — a read-only home.file symlink makes every write fail and leaves VS Code with unsaved settings
# ("save settings.json?" on each quit). `vscode-settings-drift` shows what differs from the declaration;
# `prune = true` drops undeclared keys on activation for a fully declarative file.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.vscode;
  jq = "${pkgs.jq}/bin/jq";
  declared = pkgs.writeText "vscode-settings.json" (builtins.toJSON cfg.settings);
  target = "${config.home.homeDirectory}/${cfg.settingsPath}";
  # What the last switch declared; the drift check compares the live file against it.
  stateFile = "${config.xdg.stateHome}/vscode/declared-settings.json";

  drift = pkgs.writeShellScriptBin "vscode-settings-drift" ''
    live=${lib.escapeShellArg target}
    want=${lib.escapeShellArg stateFile}
    if [ ! -f "$want" ]; then
      echo "vscode-settings-drift: no declaration recorded yet, run home-manager switch first" >&2
      exit 1
    fi
    ${jq} -n --slurpfile live "$live" --slurpfile want "$want" '
      $live[0] as $l | $want[0] as $w
      | {
          "only_in_settings_json": ($l | with_entries(select(.key as $k | $w | has($k) | not))),
          "differs_from_declaration": (
            $w | to_entries | map(select($l[.key] != .value))
            | map({key, value: {declared: .value, live: $l[.key]}}) | from_entries
          )
        }'
  '';
in
{
  options.my.vscode = {
    settings = lib.mkOption {
      type = with lib.types; attrsOf anything;
      default = { };
      description = "Declared VS Code user settings (settings.json keys).";
    };
    settingsPath = lib.mkOption {
      type = lib.types.str;
      default =
        if pkgs.stdenv.isDarwin then
          "Library/Application Support/Code/User/settings.json"
        else
          ".vscode-server/data/Machine/settings.json";
      description = "settings.json relative to the home directory.";
    };
    prune = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Drop keys that are not declared on activation instead of keeping them.";
    };
  };

  config = {
    home.packages = [ drift ];

    home.activation.vscodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      f=${lib.escapeShellArg target}
      state=${lib.escapeShellArg stateFile}
      if [[ -v DRY_RUN ]]; then
        echo "vscodeSettings: would merge declared keys into $f"
      else
        mkdir -p "$(dirname "$f")" "$(dirname "$state")"
        # The old setup linked a read-only store file here; turn it into a real file first.
        if [ -L "$f" ]; then
          content="$(cat "$f")"
          rm "$f"
          printf '%s\n' "$content" > "$f"
        fi
        [ -s "$f" ] || echo '{}' > "$f"
        tmp="$(mktemp)"
        if ${jq} -s ${
          lib.escapeShellArg (if cfg.prune then ".[1]" else ".[0] * .[1]")
        } "$f" ${declared} > "$tmp" 2>/dev/null; then
          cat "$tmp" > "$f"
        else
          # settings.json is JSONC; jq cannot read comments or trailing commas
          cp "$f" "$f.bak-$(date +%s)"
          echo "vscodeSettings: $f is not plain JSON, backed it up and rewrote it from the declaration" >&2
          cat ${declared} > "$f"
        fi
        rm -f "$tmp"
        chmod u+w "$f"
        cat ${declared} > "$state"
      fi
    '';
  };
}
