# Aspect:    none (Den schema defaults for every user and Home Manager host)
# Platforms: nixos, darwin (configures Home Manager's system integration)
# Purpose:   Declares the Home Manager input, gives every user the homeManager
#            class, and sets Home Manager's integration options on every host
#            that has users.
#
# Notes:
# - useGlobalPkgs/useUserPackages: users share the system's nixpkgs (and its
#   allowUnfree) and install packages into the per-user profile.
# - backupCommand: when a managed file would overwrite an existing unmanaged
#   one, the old file goes to the trash (or is deleted) instead of the switch
#   failing with "Existing file ... is in the way".
{
  inputs,
  lib,
  ...
}:
let
  versions = import ./_versions.nix;
in
{
  # Home Manager; the branch is set in ./_versions.nix
  flake-file.inputs.home-manager = {
    url = "github:nix-community/home-manager/${versions.home-manager}";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Every user gets Home Manager. Den imports home-manager's NixOS/nix-darwin
  # module itself (from inputs.home-manager) on hosts with such users, and
  # merges each user's `homeManager` class into home-manager.users.<name>.
  den.schema.user.classes = lib.mkDefault [ "homeManager" ];

  # Applied to every host that enables Home Manager.
  #
  # A plain attrset under `os` rather than a `{ host, ... }:` function: since
  # Den 0.20 (#694) these includes also reach the user scope, where Den wraps
  # function includes and calls them with a null context.
  den.schema.hm-host.includes = [
    {
      os =
        { pkgs, ... }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit inputs;
            };

            # When a managed file collides with an existing, unmanaged file,
            # get the existing one out of the way instead of aborting the
            # switch: move it to the trash if a trash command is available,
            # otherwise delete it. Home Manager calls this unquoted with the
            # conflicting path as $1, so it must be a single executable.
            backupCommand = pkgs.writeShellScript "home-manager-backup-command" ''
              PATH="${lib.makeBinPath [ pkgs.trash-cli ]}:$PATH:/usr/bin:/run/current-system/sw/bin"
              if command -v trash >/dev/null; then
                exec trash "$1"
              elif command -v trash-put >/dev/null; then
                exec trash-put "$1"
              else
                exec rm -rf -- "$1"
              fi
            '';
          };
        };
    }
  ];
}
