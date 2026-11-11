# Aspect:    none (flake outputs)
# Platforms: n/a
# Purpose:   Defines what the flake exports: the darwin/NixOS configurations Den
#            builds, one `nh` wrapper per host, the flake-file generators
#            (write-flake), checks, the dev shell (apply-configuration,
#            darwintron-vm, nixostron-vm, test-scripts, sops tools) and the
#            nixfmt formatter.
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

  # Lints and tests the repo's shell and Python scripts (bats, shellcheck,
  # zsh -n, unittest, ruff). The same command runs in the dev shell and in the
  # `script-tests` check; see documentation/testing-scripts.md.
  mkTestScripts =
    pkgs:
    pkgs.writeShellApplication {
      name = "test-scripts";
      runtimeInputs = [
        pkgs.bats
        # `ps`, used by update-all-magnanix to stop deployments on Ctrl-C
        pkgs.procps
        pkgs.python3
        pkgs.ruff
        pkgs.shellcheck
        pkgs.zsh
      ];
      text = builtins.readFile ../../pkgs/test-scripts.sh;
    };
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
      { pkgs, system }:
      let
        # flake-file's scripts hardcode `pkgs.nix` (stock nixpkgs Nix) in their PATH. That
        # Nix doesn't know the settings Determinate writes to /etc/nix/nix.conf
        # (lazy-trees, eval-cores, build-time-fetch-tree) and warns about them on every
        # call, so swap in Determinate's own Nix for those scripts.
        pkgsWithDeterminateNix = pkgs.extend (
          _: _: { nix = inputs.determinate.inputs.nix.packages.${system}.default; }
        );
      in
      # One `nh` wrapper per Den host / home, named after it, so that e.g.
      # `nix run .#darwintron -- switch` runs `nh darwin switch .#darwinConfigurations.darwintron`.
      config.den.lib.nh.denPackages { fromFlake = true; } pkgs
      # flake-file's generators, e.g. `nix run .#write-flake`
      // lib.mapAttrs (_: mkApp: mkApp pkgsWithDeterminateNix) config.flake-file.apps
    );

    # `nix flake check` fails when flake.nix is out of date with the modules
    # Linux systems also build the nixostron host for their architecture, so
    # `nix flake check` on a Linux host catches a nixostron that no longer builds.
    checks = forEachSupportedSystem (
      { pkgs, system }:
      {
        check-flake-file = config.flake-file.check-flake-file pkgs;

        # Shell and Python script lints and tests, run against the flake's source
        script-tests = pkgs.runCommand "script-tests" { } ''
          ${lib.getExe (mkTestScripts pkgs)} ${self}
          touch $out
        '';
      }
      // lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        nixostron =
          config.flake.nixosConfigurations."nixostron-${lib.head (lib.splitString "-" system)}".config.system.build.toplevel;
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

            # Builds and tests the disposable darwintron Tart VM. tart itself comes from
            # the system profile (the `tui.macos.tart` aspect), because it is unfree.
            (pkgs.writeShellApplication {
              name = "darwintron-vm";
              runtimeInputs = [
                pkgs.age
                pkgs.git
                pkgs.jq
                pkgs.sops
                pkgs.ssh-to-age
                pkgs.sshpass
              ];
              # Its commands are single-quoted on purpose: they expand on the guest.
              excludeShellChecks = [ "SC2016" ];
              text = builtins.readFile ../../pkgs/darwintron-vm.sh;
            })

            # Builds and tests the disposable nixostron VM: under Tart on macOS, under
            # QEMU (`nixos-rebuild build-vm`) on x86_64 NixOS hosts. tart and
            # nixos-rebuild come from the system profile.
            (pkgs.writeShellApplication {
              name = "nixostron-vm";
              runtimeInputs = [
                pkgs.age
                pkgs.git
                pkgs.jq
                pkgs.nixos-anywhere
                pkgs.sops
                pkgs.ssh-to-age
                pkgs.sshpass
              ];
              # Its commands are single-quoted on purpose: they expand on the guest.
              excludeShellChecks = [ "SC2016" ];
              text = builtins.readFile ../../pkgs/nixostron-vm.sh;
            })

            # Lints and tests the shell and Python scripts: `test-scripts`
            (mkTestScripts pkgs)

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

          # sops only uses a YubiKey when given its age-plugin-yubikey identity, so ask the
          # plugin for the identities of whichever YubiKeys are plugged in.
          env.SOPS_AGE_KEY_CMD = "age-plugin-yubikey --identity";

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
