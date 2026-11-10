# Aspect:    den.aspects.sops (added to every host via den.default.includes)
# Platforms: nixos, darwin, home-manager
# Purpose:   Imports sops-nix and points each host at secrets/hosts/<hostName>.yaml
#            and each user at secrets/users/<user>.yaml, so an aspect can
#            declare a secret without naming its file.
#
# Notes:
# - Hosts decrypt with their SSH host key; users with a per-machine age key in
#   ~/.config/sops-nix/key.txt, which must exist before the first switch.
{ den, inputs, ... }:
{
  # sops-nix for encrypted secrets, at both system and Home Manager level.
  #
  # Secret files (see .sops.yaml for who can decrypt each one):
  #   secrets/common.yaml          for secrets shared between hosts; .sops.yaml lists which hosts can decrypt it
  #   secrets/hosts/<host>.yaml    one per host, the system's default secrets file
  #   secrets/users/<user>.yaml    one per user, the Home Manager default secrets file
  #
  # To use a secret, declare it in an aspect (`host` secrets in `os`/`darwin`/`nixos`,
  # user secrets in `homeManager`). Secrets in the per-host / per-user file need no
  # `sopsFile`; secrets from the common file do:
  #
  #   den.aspects.my-feature.os.sops.secrets.my_secret = { };
  #   den.aspects.my-feature.os.sops.secrets.shared_secret.sopsFile = ../../secrets/common.yaml;
  #   den.aspects.alberth.homeManager.sops.secrets.my_user_secret = { };
  #
  # The decrypted values appear at `config.sops.secrets.<name>.path`.
  den.aspects.sops = {
    darwin.imports = [ inputs.sops-nix.darwinModules.sops ];
    nixos = {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      # nix-darwin's default is already /etc/ssh/ssh_host_ed25519_key, but NixOS only
      # derives its default from services.openssh, so set it explicitly. This is
      # static (not in an include below) because lists would concatenate duplicates.
      sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
    homeManager.imports = [ inputs.sops-nix.homeManagerModules.sops ];

    includes = [
      # System level: each host decrypts with its SSH host key converted to age,
      # the same key `.sops.yaml` lists as `host_<name>`. Keyed by hostName, not the
      # Den host name, so both nixostron hosts (one per architecture) share a file.
      (
        { host, ... }:
        {
          os.sops.defaultSopsFile = ../../secrets/hosts/${host.hostName}.yaml;
        }
      )

      # Home Manager level: each user decrypts with a per-machine age key, the same
      # key `.sops.yaml` lists as `<user>_<host>`. Create it on each machine with
      # `age-keygen -o ~/.config/sops-nix/key.txt`.
      (
        { user, ... }:
        {
          homeManager =
            { config, ... }:
            {
              sops = {
                defaultSopsFile = ../../secrets/users/${user.userName}.yaml;
                age.keyFile = "${config.xdg.configHome}/sops-nix/key.txt";
              };
            };
        }
      )
    ];
  };

  # sops-nix for encrypted secrets (system and Home Manager)
  flake-file.inputs.sops-nix = {
    url = "github:Mic92/sops-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.default.includes = [ den.aspects.sops ];
}
