{
  den.aspects.tex.texpile = {
    homeManager = { pkgs, ... }: {
      home.packages = [
        (pkgs.callPackage ../../../pkgs/texpile.nix { })
      ];
    };
  };
}
