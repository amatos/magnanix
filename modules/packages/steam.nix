{
  den.aspects.steam = {
    darwin = {
      homebrew.casks = [ "steam" ];
    };

    nixos = { pkgs, ... }: {
      packages = [ pkgs.steam ];
    };
  };
}
