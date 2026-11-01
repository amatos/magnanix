{
  den.aspects.imagemagick = {
    homeManager = { pkgs, ... }: {
      home.packages = [
        pkgs.imagemagick
      ];
    };
  };
}
