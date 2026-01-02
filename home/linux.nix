{ pkgs, lib, ... }:
{
  targets.genericLinux.enable = true;

  # VS Code integrated terminal often starts an interactive *non-login* zsh, which does not read ~/.zprofile.
  # Ensure Home Manager session vars (and thus nix.sh) are loaded in that case.
  programs.zsh.initContent = lib.mkBefore ''
    # --- Fix for VS Code Remote & Nix Environment (interactive shells) ---
    [[ -r ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]] && . ~/.nix-profile/etc/profile.d/hm-session-vars.sh
    # --------------------------------------------------------------------

    ports() {
      if ! command -v ss >/dev/null 2>&1; then
        echo "ports: 'ss' not found (install iproute2)" >&2
        return 127
      fi

      if (( EUID != 0 )) && command -v sudo >/dev/null 2>&1; then
        if command sudo ss -tulpen; then
          return 0
        fi
        echo "ports: sudo failed; running ss without sudo" >&2
      fi

      command ss -tulpen
    }
  '';

  # Some environments (notably VS Code Remote) propagate __HM_SESS_VARS_SOURCED=1 but overwrite PATH/NIX_PROFILES.
  # In that case hm-session-vars.sh becomes a no-op, so we force a re-source when NIX env is missing.
  programs.zsh.envExtra = lib.mkAfter ''
    if [[ -z "$NIX_PROFILES" || ":$PATH:" != *":$HOME/.nix-profile/bin:"* ]]; then
      unset __HM_SESS_VARS_SOURCED
      [[ -r "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]] && . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    fi
  '';

  # For login shells, keep ~/.zprofile sourcing /etc/profile and ~/.profile.
  programs.zsh.profileExtra = ''
    # --- Fix for VS Code Remote & Nix Environment (login shells) ---
    [[ -r /etc/profile ]] && emulate sh -c '. /etc/profile'
    [[ -r ~/.profile ]] && emulate sh -c '. ~/.profile'
    # --------------------------------------------------------------
  '';

  home.packages = lib.mkAfter (with pkgs; [
    iproute2
    ethtool
    bridge-utils
    dool
    sysstat
    atop
    nmon
    iotop
    ioping
  ]);

}
