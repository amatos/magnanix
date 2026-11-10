# Aspect:    den.aspects.steam
# Platforms: darwin, nixos
# Purpose:   Steam: the Homebrew cask on macOS, programs.steam on NixOS (which
#            also sets up the 32-bit libraries and udev rules for controllers).
#            Unfree.
{ den, ... }:
{
  den.aspects.steam = {
    includes = [
      (den.batteries.unfree [
        "steam"
        "steam-unwrapped"
      ])
    ];

    darwin = {
      homebrew.casks = [ "steam" ];
    };

    nixos = {
      programs.steam.enable = true;
    };
  };
}
