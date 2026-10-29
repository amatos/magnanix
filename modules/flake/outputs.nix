{
  config,
  inputs,
  lib,
  self,
  ...
}:
let
  # Systems the dev shell, formatter and packages are built for
  supportedSystems = [
    "aarch64-darwin"
    "x86_64-linux"
    "aarch64-linux"
  ];
  forEachSupportedSystem =
    f:
    lib.genAttrs supportedSystems (
      system:
      f {
        inherit system;
        pkgs = import inputs.nixpkgs { inherit system; };
      }
    );
in
{
  # The flake's outputs. flake.nix is generated and ends with
  # `(evalModules ...).config.outputs inputs`, so this is the real `outputs`
  # function. Hosts, users and features are Den aspects declared elsewhere in
  # ./modules; Den builds the system configurations and exposes them as
  # `config.flake`.
  outputs = _inputs: {
    # System configuration outputs, one per Den host. The host names must match
    # `scutil --get LocalHostName` (macOS) or `hostname` (NixOS) so that
    # `darwin-rebuild` / `nixos-rebuild` pick them up.
    inherit (config.flake) darwinConfigurations nixosConfigurations;

    packages = forEachSupportedSystem (
      { pkgs, ... }:
      # One `nh` wrapper per Den host / home, named after it, so that e.g.
      # `nix run .#darwintron -- switch` runs `nh darwin switch .#darwinConfigurations.darwintron`.
      config.den.lib.nh.denPackages { fromFlake = true; } pkgs
      # flake-file's generators, e.g. `nix run .#write-flake`
      // lib.mapAttrs (_: mkApp: mkApp pkgs) config.flake-file.apps
    );

    # `nix flake check` fails when flake.nix is out of date with the modules
    checks = forEachSupportedSystem (
      { pkgs, ... }:
      {
        check-flake-file = config.flake-file.check-flake-file pkgs;
      }
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

            pkgs.git

            self.formatter.${system}
          ];

          # Enable the tracked pre-commit hook (.githooks/pre-commit)
          shellHook = ''
            if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
              && [ "$(git config core.hooksPath || true)" != ".githooks" ]; then
              git config core.hooksPath .githooks
            fi
          '';
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
