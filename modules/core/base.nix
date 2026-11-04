# Always installed: Home Manager itself, GNU userland parity and the everyday CLI.
{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.my = {
    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/codes/home-managed";
      description = "Where this repo is checked out; scripts referenced by aliases live under it.";
    };
    docs.enable = lib.mkEnableOption ''
      generated man pages (home-configuration.nix(5), nixvim(5)); building them pulls pandoc and a
      docs toolchain'';
    gpu.enable = lib.mkEnableOption ''
      GPU drivers for Nix-built GUI/GL apps on non-NixOS Linux (mesa + LLVM, ~0.8 GiB); not needed on
      headless machines or macOS'';
  };

  config = {
    manual.manpages.enable = config.my.docs.enable;
    programs.home-manager.enable = true;
    news.display = "silent";
    home.activation.installPackages = lib.mkForce (
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        if config.submoduleSupport.externalPackageInstall then
          ''
            nixProfileRemove home-manager-path
          ''
        else
          ''
            function nixReplaceProfile() {
              local oldNix="$(command -v nix)"

              nixProfileRemove 'home-manager-path'

              run $oldNix profile add $1
            }

            if [[ -e ${config.home.profileDirectory}/manifest.json ]] ; then
              INSTALL_CMD="nix profile add"
              INSTALL_CMD_ACTUAL="nixReplaceProfile"
              LIST_CMD="nix profile list"
              REMOVE_CMD_SYNTAX='nix profile remove {number | store path}'
            else
              INSTALL_CMD="nix-env -i"
              INSTALL_CMD_ACTUAL="run nix-env -i"
              LIST_CMD="nix-env -q"
              REMOVE_CMD_SYNTAX='nix-env -e {package name}'
            fi

            if ! $INSTALL_CMD_ACTUAL ${config.home.path} ; then
              echo
              _iError $'Oops, Nix failed to install your new Home Manager profile!\n\nPerhaps there is a conflict with a package that was installed using\n"%s"? Try running\n\n    %s\n\nand if there is a conflicting package you can remove it with\n\n    %s\n\nThen try activating your Home Manager configuration again.' "$INSTALL_CMD" "$LIST_CMD" "$REMOVE_CMD_SYNTAX"
              exit 1
            fi
            unset -f nixReplaceProfile
            unset INSTALL_CMD INSTALL_CMD_ACTUAL LIST_CMD REMOVE_CMD_SYNTAX
          ''
      )
    );

    home.shellAliases = {
      sudo = "sudo -E";
      # Base muscle memory
      ls = "eza";
      ll = "eza -lah --group-directories-first";
      cat = "bat";
      # grep = "rg";  # Disabled: too common, use native command
      # find = "fd";   # Disabled: too common, use native command

      # Observability
      top = "btop";
      # df = "duf";    # Disabled: too common, use native command
      # du = "dust";   # Disabled: too common, use native command

      # Git workflow
      g = "git";
      gs = "git status -sb";
      gd = "git diff";
      gl = "git log --oneline --graph --decorate";
      lg = "lazygit";

      # Networking quick checks (curl only; dig/nexttrace aliases live in the net component)
      myip = "curl -fsSL ifconfig.me | sed 's/%.*$//'";
      myip4 = "curl -4 -fsSL ifconfig.me | sed 's/%.*$//'";
      myip6 = "curl -6 -fsSL ifconfig.me | sed 's/%.*$//'";
    };

    home.packages = with pkgs; [
      coreutils
      findutils
      gnugrep
      gnused
      gawk
      less
      tree
      watch
      ripgrep
      fd
      bat
      eza
      dust
      ncdu
      duf
      gh
      git-open
      btop
      lazygit
      curl
      wget
      openssl
    ];
  };
}
