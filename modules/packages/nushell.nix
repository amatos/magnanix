{
  den.aspects.nushell = {
    homeManager = { pkgs, ... }: {
      home.packages = [
        pkgs.nushell
      ];
    };
  };
}
