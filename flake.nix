{
  description = "magnanix: nix-darwin, NixOS and Home Manager on Determinate Nix";

  # Flake inputs
  inputs = {
    # Unstable Nixpkgs (nixpkgs-unstable; use 0 for stable)
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    # Unstable nix-darwin (master; use 0 for stable)
    nix-darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Unstable Home Manager (master; use 0 for stable)
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Determinate 3.* module
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # sops-nix for encrypted secrets (system and Home Manager)
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nix-homebrew installs and manages Homebrew itself on macOS
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Den is an aspect-oriented Nix framework: write features, not host files
    den.url = "github:denful/den";
    # import-tree auto-loads every module under ./modules
    import-tree.url = "github:denful/import-tree";
  };

  # Flake outputs
  outputs =
    { self, ... }@inputs:
    let
      # Evaluate every module under ./modules. Hosts, users and features are all
      # declared there as Den aspects; Den builds the system configurations.
      denConfig =
        (inputs.nixpkgs.lib.evalModules {
          modules = [ (inputs.import-tree ./modules) ];
          specialArgs = { inherit inputs; };
        }).config;

      # Systems the dev shell and formatter are built for
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import inputs.nixpkgs { inherit system; };
          }
        );
    in
    {
      # System configuration outputs, one per Den host. The host names must match
      # `scutil --get LocalHostName` (macOS) or `hostname` (NixOS) so that
      # `darwin-rebuild` / `nixos-rebuild` pick them up.
      inherit (denConfig.flake) darwinConfigurations nixosConfigurations;

      # One `nh` wrapper per Den host / home, named after it, so that e.g.
      # `nix run .#darwintron -- switch` runs `nh darwin switch .#darwinConfigurations.darwintron`.
      packages = forEachSupportedSystem (
        { pkgs, ... }: denConfig.den.lib.nh.denPackages { fromFlake = true; } pkgs
      );

      # Development environment
      devShells = forEachSupportedSystem (
        { system, pkgs }:
        {
          default = pkgs.mkShellNoCC {
            packages = [
              (
                if pkgs.stdenv.hostPlatform.isDarwin then
                  # Shell script for applying the nix-darwin configuration (which includes Home Manager).
                  # Run this to apply the configuration in this flake to your macOS system:
                  # nix develop --command apply-configuration
                  pkgs.writeShellApplication {
                    name = "apply-configuration";
                    runtimeInputs = [
                      # Make the darwin-rebuild package available in the script
                      inputs.nix-darwin.packages.${system}.darwin-rebuild
                    ];
                    text = ''
                      host="$(scutil --get LocalHostName)"

                      echo "> Applying nix-darwin configuration for $host..."

                      echo "> Running darwin-rebuild switch as root..."
                      sudo darwin-rebuild switch --flake ".#$host"
                      echo "> darwin-rebuild switch was successful ✅"

                      echo "> macOS config was successfully applied 🚀"
                    '';
                  }
                else
                  # Shell script for applying the NixOS configuration (which includes Home Manager).
                  # Run this on a NixOS host to apply the configuration in this flake:
                  # nix develop --command apply-configuration
                  pkgs.writeShellApplication {
                    name = "apply-configuration";
                    text = ''
                      host="$(hostname)"

                      echo "> Applying NixOS configuration for $host..."

                      echo "> Running nixos-rebuild switch as root..."
                      sudo nixos-rebuild switch --flake ".#$host"
                      echo "> nixos-rebuild switch was successful ✅"

                      echo "> NixOS config was successfully applied 🚀"
                    '';
                  }
              )

              # Tools for creating and editing secrets
              pkgs.sops
              pkgs.age
              pkgs.age-plugin-yubikey
              pkgs.ssh-to-age
              # Hashing login passwords (`openssl passwd -6`)
              pkgs.openssl

              self.formatter.${system}
            ];
          };
        }
      );

      # Nix formatter

      # This applies the formatter that follows RFC 166, which defines a standard format:
      # https://github.com/NixOS/rfcs/pull/166

      # To format all Nix files:
      # git ls-files -z '*.nix' | xargs -0 -r nix fmt
      # To check formatting:
      # git ls-files -z '*.nix' | xargs -0 -r nix develop --command nixfmt --check
      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt);
    };
}
