# User:      ephemeral (den.aspects.ephemeral)
# Platforms: nixos, darwin, home-manager
# Purpose:   Disposable test user for the darwintron and nixostron VMs. Its
#            secrets (secrets/users/ephemeral.yaml) hold fake values only.
#
# Notes:
# - Login shell is Nix's zsh, set the same way as alberth's.
# - NixOS: throwaway password "ephemeral" (not a secret) and the test VMs'
#   access key, because base makes users immutable and NixOS refuses to build
#   unless an admin account can log in.
{ den, ... }:
let
  username = "ephemeral";

  # The public half of darwintron-vm's `access_key` (secrets/bootstrap/darwintron.yaml),
  # which darwintron-vm also installs for ephemeral on darwintron.
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLC6jn4Ou9a2oEDMz4DWwQ7zcrUgz5VG+nEBvC1vmbw darwintron-vm-access"
  ];
in
{
  den.aspects.ephemeral = {
    includes = [
      den.batteries.define-user
      den.batteries.host-aspects
    ];

    homeManager = {
      # Set to the release ephemeral's Home Manager was first set up with
      home.stateVersion = "26.05";
    };

    user = {
      createHome = true;
      description = "Ephemeral test user";
    };

    os =
      { pkgs, ... }:
      {
        users.users.${username}.shell = pkgs.zsh;
      };

    # Login password and SSH key on NixOS, where base sets users.mutableUsers = false
    # and NixOS refuses to build unless an admin account can log in. The password is
    # "ephemeral", the same throwaway, non-secret value darwintron-vm gives the
    # account on darwintron (nix-darwin never manages passwords).
    nixos.users.users.${username} = {
      hashedPassword = "$y$j9T$LDZMojrmE41Crt1k5Nueg1$G4AhHBBQfsAz7cGooM4ZqyyIExq2GeybPfjrvvCz4a.";
      openssh.authorizedKeys.keys = authorizedKeys;
    };

    # See the matching block in modules/users/alberth/alberth.nix.
    darwin =
      { pkgs, ... }:
      {
        environment.shells = [ pkgs.zsh ];

        system.activationScripts.postActivation.text = ''
          if [ "$(dscl . -read /Users/${username} UserShell)" != "UserShell: /run/current-system/sw/bin/zsh" ]; then
            echo "setting ${username}'s login shell to Nix zsh..." >&2
            dscl . -create /Users/${username} UserShell /run/current-system/sw/bin/zsh
          fi
        '';
      };
  };
}
