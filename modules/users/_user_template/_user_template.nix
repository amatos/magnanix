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
