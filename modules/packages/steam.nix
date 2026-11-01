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
