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

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      home-manager,
      nixvim,
      nix-index-database,
      ...
    }:
    let
      lib = nixpkgs.lib;

      # twisted's test suite fails on darwin, so Hydra has no darwin binary for it (or anything that
      # depends on it). On Linux the cached build is fine, and overriding it there would only force
      # local rebuilds of glances & co, so the override is darwin-only.
      twistedNoChecksOverlay =
        final: prev:
        let
          disableTwistedChecks =
            python:
            python.override {
              packageOverrides = pyFinal: pyPrev: {
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
        // (
          if prev ? python313 then
            {
              python313 = python313;
              python313Packages = python313.pkgs;
            }
          else
            { }
        );

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = lib.optional (lib.hasSuffix "-darwin" system) twistedNoChecksOverlay;
          config = {
            allowUnfreePredicate =
              pkg:
              builtins.elem (lib.getName pkg) [
                "copilot.vim"
              ];
          };
        };

      # `modules` selects what gets installed: a preset (presets/*.nix) or a host file (hosts/*.nix).
      mkHome =
        {
          system ? builtins.currentSystem,
          username ? envUser,
          homeDirectory ? envHome,
          modules,
        }:
        let
          pkgs = mkPkgs system;
          osModule =
            if pkgs.stdenv.isDarwin then ./modules/platform/darwin.nix else ./modules/platform/linux.nix;
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            nixvim.homeModules.nixvim
            nix-index-database.homeModules.nix-index
            ./modules
            osModule
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
              home.stateVersion = "23.11";
            }
          ]
          ++ modules;
        };

      envUser = builtins.getEnv "USER";
      envHome = builtins.getEnv "HOME";

      presets = {
        minimal = [ ./presets/minimal.nix ];
        dev = [ ./presets/dev.nix ];
        full = [ ./presets/full.nix ];
      };

      # Every hosts/<name>.nix becomes homeConfigurations.<name>; files starting with `_` are skipped.
      hosts =
        lib.mapAttrs'
          (file: _: {
            name = lib.removeSuffix ".nix" file;
            value = mkHome { modules = [ (./hosts + "/${file}") ]; };
          })
          (
            lib.filterAttrs (
              file: type: type == "regular" && lib.hasSuffix ".nix" file && !lib.hasPrefix "_" file
            ) (builtins.readDir ./hosts)
          );

      current = import ./lib/current.nix {
        inherit lib;
        home = envHome;
        user = envUser;
      };
    in
    {
      homeConfigurations = {
        # Last applied selection / inferred from an existing install / minimal; see lib/current.nix.
        current = mkHome {
          modules = [ (builtins.trace "home-managed .#current: ${current.source}" current.module) ];
        };
        minimal = mkHome { modules = presets.minimal; };
        dev = mkHome { modules = presets.dev; };
        full = mkHome { modules = presets.full; };
        k3s = mkHome { modules = presets.full ++ [ { my.k8s.cilium = true; } ]; };
        user-linux = mkHome {
          system = "x86_64-linux";
          modules = presets.full;
        };
        user-mac = mkHome {
          system = "aarch64-darwin";
          modules = presets.full;
        };
        user-mac-intel = mkHome {
          system = "x86_64-darwin";
          modules = presets.full;
        };
      }
      // hosts
      // lib.optionalAttrs (envUser != "") {
        ${envUser} = mkHome { modules = presets.full; };
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = mkPkgs system;
        nvim = nixvim.legacyPackages.${system}.makeNixvim (import ./nixvim.nix { inherit pkgs; });
      in
      {
        packages.nvim = nvim;
        apps.nvim = {
          type = "app";
          program = "${nvim}/bin/nvim";
        };
      }
    );
}
