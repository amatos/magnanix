{ den, ... }:
let
  # Defined here (rather than read back through `config`) so the same values can
  # be used both as aspect metadata and inside this aspect's own definitions,
  # including attribute names, without risking infinite recursion.
  meta = {
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILfxNl1S0Fvzh2aOAG6FuIwB96eqnUqY1nl2p2jSnTOD"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJmQ75w1oH1osbRwMjjem52/8Oc8YYbmTbMxSIEw9Xy8 alberth@darwintron"
    ];

    email = "alberth@matos.cc";
    fullName = "Alberth Matos";
    gpgKey = "F41BDBF6171A3BB4"; # ed25519/0xF41BDBF6171A3BB4
    gpgFingerprint = "5FC8FE1141FA769594E91E48F41BDBF6171A3BB4";
    gpgPublicKey = ./F41BDBF6171A3BB4.pub.asc;

    username = "alberth";
  };
in
{
  den.aspects.alberth = {
    inherit meta;

    # OS-level account (users.users.alberth with its home directory) plus
    # home.username / home.homeDirectory for Home Manager.
    includes = [
      den.batteries.define-user
      den.batteries.primary-user

      den.aspects.gpg
      den.aspects._1password
    ];

    # Home Manager configuration for alberth
    homeManager =
      { pkgs, ... }:
      {
        # Set to the release alberth's Home Manager was first set up with
        home.stateVersion = "26.05";

        home.packages = [ pkgs.htop ];
      };

    user = {
      createHome = true;
      description = meta.fullName;

      # initialPassword = "id";
    };

    # extraGroups and openssh are NixOS-only users.users options
    # (not supported by nix-darwin's users.users submodule).
    nixos.users.users.${meta.username} = {
      extraGroups = [
        "dialout" # Or else: Permission denied: ‘/dev/ttyUSB0’
        "input"
        "tty"
      ];

      openssh.authorizedKeys.keys = meta.authorizedKeys;
    };
  };
}
