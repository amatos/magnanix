# Aspect:    none (flake outputs)
# Platforms: n/a
# Purpose:   Defines what the flake exports: the darwin/NixOS configurations Den
#            builds, one `nh` wrapper per host, the flake-file generators
#            (write-flake), checks, the dev shell (apply-configuration,
#            darwintron-vm, nixostron-vm, test-scripts, sops tools) and the
#            nixfmt formatter wrapper.
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

    # What the `secrets` command (nix-secrets) edits and rekeys against: a minimal
    # configuration with every registry secret enabled, so the CLI sees every secret
    # with the same recipients the hosts get (see modules/den/_nix-secrets-shared.nix).
    # One per system, because the CLI builds the manifest with the local system's
    # pkgs: nix-darwin on macOS, NixOS on Linux. Never deployed.
    secretsAdmin = forEachSupportedSystem (
      { system, ... }:
      let
        isDarwin = lib.hasSuffix "-darwin" system;
        registry = import ../den/_secrets-registry.nix;
      in
      (if isDarwin then inputs.nix-darwin.lib.darwinSystem else inputs.nixpkgs.lib.nixosSystem) {
        modules = [
          (
            if isDarwin then
              inputs.nix-secrets.darwinModules.default
            else
              inputs.nix-secrets.nixosModules.default
          )
          {
            nixpkgs.hostPlatform = system;
            system.stateVersion = if isDarwin then 7 else "26.05";
            security.nix-secrets = import ../den/_nix-secrets-shared.nix { inherit inputs lib; } // {
              # The `secrets` command passes the YubiKey identities with --identity.
              identityPaths = [ ];
              activate.enable = false;
            };
          }
          { security.nix-secrets.secrets = lib.mapAttrs (_: _: { enable = true; }) registry.secrets; }
        ]
        ++ lib.optional (!isDarwin) { boot.isContainer = true; };
      }
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

        # A VM test of den.aspects.game-streaming: headless Sway and Sunshine, no
        # Steam. It needs KVM; see documentation/game-streaming.md.
        game-streaming = import ./_game-streaming-test.nix {
          inherit pkgs;
          gameStreaming = config.den.aspects.game-streaming.nixos;
        };
      }
    );

    # Development environment
    devShells = forEachSupportedSystem (
      { system, pkgs }:
      let
        # The age identities of the plugged-in YubiKeys, for sops (SOPS_AGE_KEY_CMD) and
        # `secrets`. With more than one plugged in, the plugin tries them in its own
        # order, so when the preferred one (13125942, which needs no PIN or touch) is
        # there, only its identity is printed. Override with YUBIKEY_PREFERRED_SERIAL.
        yubikeyIdentities = pkgs.writeShellApplication {
          name = "yubikey-identities";
          runtimeInputs = [
            pkgs.age-plugin-yubikey
            pkgs.gnugrep
          ];
          text = ''
            preferred="''${YUBIKEY_PREFERRED_SERIAL:-13125942}"
            # --identity --serial exits 0 with no output for a key that isn't plugged in,
            # so check the list first. Captured rather than piped: `grep -q` stops at the
            # first match, and under pipefail the plugin's SIGPIPE would fail the test.
            keys="$(age-plugin-yubikey --list 2>/dev/null || true)"
            if grep -q "Serial: $preferred," <<<"$keys"; then
              exec age-plugin-yubikey --identity --serial "$preferred"
            fi
            exec age-plugin-yubikey --identity
          '';
        };
      in
      {
        default = pkgs.mkShellNoCC {
          packages = [
            (
              if pkgs.stdenv.hostPlatform.isDarwin then
                # Shell script for applying the nix-darwin configuration (which includes Home Manager).
                # Run this to apply the configuration in this flake to your macOS system:
                # nix develop --command apply-configuration
                # Extra arguments go to darwin-rebuild (e.g. --override-input secrets path:...).
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
                    sudo darwin-rebuild switch --flake ".#$host" "$@"
                    echo "> darwin-rebuild switch was successful ✅"

                    echo "> macOS config was successfully applied 🚀"
                  '';
                }
              else
                # Shell script for applying the NixOS configuration (which includes Home Manager).
                # Run this on a NixOS host to apply the configuration in this flake:
                # nix develop --command apply-configuration
                # Extra arguments go to nixos-rebuild (e.g. --override-input secrets path:...).
                pkgs.writeShellApplication {
                  name = "apply-configuration";
                  text = ''
                    host="$(hostname)"

                    echo "> Applying NixOS configuration for $host..."

                    echo "> Running nixos-rebuild switch as root..."
                    sudo nixos-rebuild switch --flake ".#$host" "$@"
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

            # nix-secrets, run against the `secretsAdmin` output so every secret is in
            # reach with its registry recipients: `secrets edit <name>`, `secrets rekey`,
            # `secrets decrypt <name>`. See documentation/NIX_SECRETS_PLAN.md.
            (pkgs.writeShellApplication {
              name = "secrets";
              runtimeInputs = [
                (inputs.nix-secrets.packages.${system}.nix-secrets.override {
                  extraPackages = [
                    pkgs.age
                    pkgs.age-plugin-yubikey
                  ];
                })
                yubikeyIdentities
                pkgs.git
              ];
              text = ''
                repo="$(git rev-parse --show-toplevel)"
                # Where `edit` and `rekey` write: a clone of amatos/secrets (git@github.com:amatos/secrets.git).
                export NIX_SECRETS_STORAGE_PATH="''${NIX_SECRETS_STORAGE_PATH:-$HOME/Developer/secrets}"
                if [ ! -d "$NIX_SECRETS_STORAGE_PATH" ]; then
                  echo "secrets: no storage at $NIX_SECRETS_STORAGE_PATH; clone amatos/secrets there or set NIX_SECRETS_STORAGE_PATH" >&2
                  exit 1
                fi

                # The plugged-in YubiKeys' identities (the preferred one alone if it is
                # there). nix-secrets skips identity paths that aren't regular files, so
                # this can't be a process substitution. They only point at a key on a
                # YubiKey, so they aren't secret; the file is removed anyway.
                identities="$(mktemp)"
                trap 'rm -f "$identities"' EXIT
                yubikey-identities >"$identities" 2>/dev/null || true

                nix-secrets --module-system secretsAdmin --flake "$repo#${system}" \
                  --identity "$identities" "$@"
              '';
            })

            # Tools for creating and editing secrets
            pkgs.sops
            pkgs.age
            pkgs.age-plugin-yubikey
            yubikeyIdentities
            pkgs.ssh-to-age
            # Hashing login passwords (`openssl passwd -6`)
            pkgs.openssl

            pkgs.git

            self.formatter.${system}
          ];

          # sops only uses a YubiKey when given its age-plugin-yubikey identity, so ask the
          # plugin for the identities of the plugged-in YubiKeys (the preferred one alone
          # if it is there; see yubikey-identities above).
          env.SOPS_AGE_KEY_CMD = "yubikey-identities";

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

    # nixfmt, the formatter that follows RFC 166, which defines a standard format:
    # https://github.com/NixOS/rfcs/pull/166

    # Plain nixfmt reads stdin when given no files, so a bare `nix fmt` waits
    # forever. This wrapper runs it on every tracked .nix file instead when no
    # file is given (options such as --check still apply); with files, or `-`
    # for stdin, it is nixfmt unchanged. It is named nixfmt so the dev shell's
    # `nixfmt` behaves the same way. See documentation/architecture.md#formatting,
    # which also covers treefmt as a possible replacement.
    #   nix fmt                  # format every tracked .nix file
    #   nix fmt -- --check       # check them
    #   nix fmt path/to/file.nix # format just that file
    formatter = forEachSupportedSystem (
      { pkgs, ... }:
      pkgs.writeShellApplication {
        name = "nixfmt";
        runtimeInputs = [
          pkgs.findutils
          pkgs.git
        ];
        text = ''
          nixfmt=${lib.getExe pkgs.nixfmt}

          # Any argument that isn't an option (or is `-`, stdin) is a file to format.
          for arg in "$@"; do
            case "$arg" in
              - | [!-]*) exec "$nixfmt" "$@" ;;
            esac
          done

          if ! root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
            echo "nixfmt: no files given and not inside a git repository" >&2
            exit 1
          fi
          cd "$root"
          git ls-files -z '*.nix' | xargs -0 -r "$nixfmt" "$@"
        '';
      }
    );
  };
}
