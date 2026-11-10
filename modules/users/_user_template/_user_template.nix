# User:      template for a new user (ignored by import-tree: leading `_`)
# Platforms: nixos, darwin, home-manager
# Purpose:   Copy this directory to modules/users/<username>/ and replace
#            CHANGE_USERNAME. Add the user to a host with
#            den.hosts.<system>.<host>.users.<username> = { };. See
#            documentation/adding-hosts-and-users.md.
#
# Notes:
# - Include den.batteries.host-aspects if the user should get the homeManager
#   parts of the host's apps.
# - A `meta` set (see alberth.nix) lets shared aspects like git and gpg adapt
#   to the user.
{ den, ... }:
{
  den.aspects.CHANGE_USERNAME = {
    # OS-level account (users.users.CHANGE_USERNAME with its home directory) plus
    # home.username / home.homeDirectory for Home Manager.
    includes = [ den.batteries.define-user ];

    # Home Manager configuration for CHANGE_USERNAME
    homeManager = {
      # Set to the release CHANGE_USERNAME's Home Manager was first set up with
      home.stateVersion = "26.05";
    };
  };
}
