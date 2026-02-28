{
  description = "Home Manager + Nixvim configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, home-manager, nixvim, nix-index-database }:
    let
      twistedNoChecksOverlay =
        final: prev:
        let
          disableTwistedChecks =
            python:
            python.override {
              packageOverrides =
                pyFinal: pyPrev:
                {
                  twisted = pyPrev.twisted.overridePythonAttrs (old: {
                    doCheck = false;
                    doInstallCheck = false;
                  });
                };
            };

          python3 = disableTwistedChecks prev.python3;
          python313 = if prev ? python313 then disableTwistedChecks prev.python313 else null;
        in
        {
          python3 = python3;
          python3Packages = python3.pkgs;
        }
        // (if prev ? python313 then {
          python313 = python313;
          python313Packages = python313.pkgs;
        } else { });

      mkHome = { system, username, homeDirectory }:
        let
          lib = nixpkgs.lib;
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ twistedNoChecksOverlay ];
            config = {
              allowUnfreePredicate = pkg:
                builtins.elem (lib.getName pkg) [
                  "copilot.vim"
                ];
            };
          };
          osModule = if pkgs.stdenv.isDarwin then ./home/darwin.nix else ./home/linux.nix;
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            nixvim.homeModules.nixvim
            nix-index-database.homeModules.nix-index
            ./home/common.nix
            osModule
            ({
              home.username = username;
              home.homeDirectory = homeDirectory;
              home.stateVersion = "23.11";
            })
          ];
        };

      envUser = builtins.getEnv "USER";
      envHome = builtins.getEnv "HOME";
    in
    {
      homeConfigurations = {
        current = mkHome {
          system = builtins.currentSystem;
          username = envUser;
          homeDirectory = envHome;
        };
        user-linux = mkHome {
          system = "x86_64-linux";
          username = envUser;
          homeDirectory = envHome;
        };
        user-mac = mkHome {
          system = "aarch64-darwin";
          username = envUser;
          homeDirectory = envHome;
        };
        user-mac-intel = mkHome {
          system = "x86_64-darwin";
          username = envUser;
          homeDirectory = envHome;
        };
      } // builtins.listToAttrs (
        if envUser != "" then [
          {
            name = envUser;
            value = mkHome {
              system = builtins.currentSystem;
              username = envUser;
              homeDirectory = envHome;
            };
          }
        ] else [ ]
      );
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        lib = nixpkgs.lib;
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ twistedNoChecksOverlay ];
          config = {
            allowUnfreePredicate = pkg:
              builtins.elem (lib.getName pkg) [
                "copilot.vim"
              ];
          };
        };
        nvim = nixvim.legacyPackages.${system}.makeNixvim
          (import ./nixvim.nix { inherit pkgs; });
      in
      {
        packages.nvim = nvim;
        apps.nvim = { type = "app"; program = "${nvim}/bin/nvim"; };
      });
}
