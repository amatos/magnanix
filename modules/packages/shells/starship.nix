# Aspect:    den.aspects.shell.starship (included by each shell aspect)
# Platforms: home-manager
# Purpose:   The Starship prompt for every shell (Home Manager hooks it into each
#            enabled shell), with Starship's default configuration.
#
# Notes:
# - Users can layer their own settings on top from their user aspect, e.g.
#   den.aspects.alberth.starship in modules/users/alberth/configs/starship.nix.
{
  den.aspects.shell.starship = {
    homeManager.programs.starship.enable = true;
  };
}
