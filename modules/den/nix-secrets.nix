# Aspect:    den.aspects.nix-secrets (added to every host via den.default.includes)
# Platforms: nixos, darwin, home-manager
# Purpose:   Imports nix-secrets and gives every configuration the shared
#            storage and registry (see _nix-secrets-shared.nix), so an aspect
#            only enables the secrets it uses:
#
#              os.security.nix-secrets.secrets."hosts/<host>/<name>".enable = true;
#              homeManager.security.nix-secrets.secrets."users/<user>/<name>".enable = true;
#
#            The decrypted value is at `config.security.nix-secrets.secrets.<name>.path`.
#
# Notes:
# - A secret also needs an entry in _secrets-registry.nix (its recipients) and a
#   file in amatos/secrets; see documentation/secrets.md.
# - Every registry secret is declared, disabled; enabling one whose `.enc` file
#   isn't in the locked `secrets` input fails evaluation.
# - Hosts decrypt with their SSH host key; users with the per-machine age key
#   sops-nix used (~/.config/sops-nix/key.txt).
# - No `restartUnits`: on NixOS, give a unit that reads a secret
#   `restartTriggers = [ (config.local.nix-secrets.restartTrigger "<name>") ]`,
#   which changes whenever the secret's file in the storage does.
{
  den,
  inputs,
  lib,
  ...
}:
let
  versions = import ./_versions.nix;
  shared = import ./_nix-secrets-shared.nix { inherit inputs lib; };
  hostIdentity = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # WORKAROUNDS below: see documentation/NIX_SECRETS_PLAN.md, D8. When a release fixes
  # them, the patch stops applying and darwin builds fail; drop both then.
  #
  # WORKAROUND (v0.5.4, upstream issue #9): on Darwin the activation tool marks the
  # RAM disk it mounts on the generations directory with an anchor file, then fails
  # parsing that file as a generation number, so no secret ever activates. Both the
  # nix-darwin daemon and the Home Manager agent mount one. The patch skips the anchor.
  darwinActivatePackage =
    { config, pkgs }:
    pkgs.callPackage "${inputs.nix-secrets}/packages/nix-secrets-activate.nix" {
      inherit (config.security.nix-secrets) extraPackages;
      unwrapped =
        (pkgs.callPackage "${inputs.nix-secrets}/packages/nix-secrets-activate-unwrapped.nix" { })
        .overrideAttrs
          (old: {
            patches = (old.patches or [ ]) ++ [ ../../pkgs/patches/nix-secrets-skip-darwin-anchor.patch ];
          });
    };
in
{
  den.aspects.nix-secrets = {
    darwin =
      { config, pkgs, ... }:
      {
        imports = [ inputs.nix-secrets.darwinModules.default ];
        security.nix-secrets = shared // {
          # Set explicitly: the default reads services.openssh.hostKeys.
          identityPaths = hostIdentity;
          activate.package = darwinActivatePackage { inherit config pkgs; };
        };
      };

    nixos = {
      imports = [ inputs.nix-secrets.nixosModules.default ];

      options.local.nix-secrets.restartTrigger = lib.mkOption {
        type = lib.types.functionTo lib.types.str;
        readOnly = true;
        default = name: builtins.hashFile "sha256" "${inputs.secrets}/${name}.enc";
        description = ''
          A value for a unit's `restartTriggers` that changes with the encrypted
          secret `name`, so the unit restarts after the secret is edited or rekeyed.
          nix-secrets has no `restartUnits`. The activation script writes the new
          value before switch-to-configuration restarts the unit.
        '';
      };

      config.security.nix-secrets = shared // {
        identityPaths = hostIdentity;
      };
    };

    homeManager =
      { config, pkgs, ... }:
      {
        imports = [ inputs.nix-secrets.homeManagerModules.default ];
        security.nix-secrets = shared // {
          identityPaths = [ "${config.xdg.configHome}/sops-nix/key.txt" ];
          # The default reads osConfig.users.users.<user>.group, which nix-darwin
          # doesn't have.
          defaultGroup = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "staff";
          activate.package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (darwinActivatePackage {
            inherit config pkgs;
          });
        };

        # WORKAROUND (v0.5.4): the module sets the agent's `Program` to the whole
        # command line, which Home Manager quotes as one path, so launchd fails with
        # exit 126. Pass the same command as separate arguments instead (store paths
        # have no spaces).
        launchd.agents.nix-secrets-activate.config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
          Program = lib.mkForce null;
          ProgramArguments = lib.splitString " " (config.security.nix-secrets.activate.command false);
        };
      };
  };

  den.default.includes = [ den.aspects.nix-secrets ];

  # nix-secrets for encrypted secrets (system and Home Manager); tag in _versions.nix
  flake-file.inputs.nix-secrets = {
    url = "github:unnamed-systems/nix-secrets/${versions.nix-secrets}";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # The encrypted secrets (the `storage`). Private: hosts fetch it with the token from
  # the nix-access-tokens aspect, CI with SECRETS_REPO_TOKEN. Update it with
  # `nix flake update secrets` after pushing amatos/secrets.
  flake-file.inputs.secrets = {
    url = "github:amatos/secrets";
    flake = false;
  };
}
