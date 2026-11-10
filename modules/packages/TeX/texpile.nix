# Aspect:    den.aspects.tex.texpile (part of den.aspects.tex)
# Platforms: home-manager
# Purpose:   Installs Texpile, packaged locally in pkgs/texpile.nix (update
#            steps are at the top of that file).
{
  den.aspects.tex.texpile = {
    homeManager = { pkgs, ... }: {
      home.packages = [
        (pkgs.callPackage ../../../pkgs/texpile.nix { })
      ];
    };
  };
}
