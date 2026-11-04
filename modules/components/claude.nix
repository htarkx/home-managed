{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.my.claude.enable = lib.mkEnableOption "Claude Code (installed by claude.ai/install.sh on activation)";

  config = lib.mkIf config.my.claude.enable {
    # claude.ai/install.sh shells out to a moving target of utilities
    # (curl/wget for fetch, shasum for checksum verify, mkdir/cp/etc for
    # placement, possibly tar/gzip for unpack). The home-manager activation
    # PATH doesn't include the user profile binaries until installPackages,
    # and even then the running script's env is frozen — so the bash
    # subshell that runs install.sh sees a stripped PATH and fails.
    #
    # Fix: explicit PATH built from (a) nix store bin/ for the utilities
    # we know it needs, plus (b) /usr/bin:/bin as a system fallback for
    # anything the upstream script might add later. Robust to claude.ai's
    # script evolving its dependency set.
    home.activation.installClaude = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if ! [ -e "$HOME/.local/bin/claude" ]; then
        (
          export PATH="${
            lib.makeBinPath (
              with pkgs;
              [
                curl
                wget
                coreutils
                gnused
                gnugrep
                gawk
                gnutar
                gzip
                which
                perl # shasum (claude.ai/install.sh uses for checksum verify)
              ]
            )
          }:/usr/bin:/bin:$PATH"
          curl -fsSL https://claude.ai/install.sh | bash
        )
      fi
    '';
  };
}
