# Aspect:    den.aspects.macos.skim
# Platforms: darwin
# Purpose:   Skim, a PDF reader and annotator, from nixpkgs (skimpdf). Works
#            with LaTeX editors for SyncTeX forward/inverse search.
{
  den.aspects.macos.skim = {
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.skimpdf ];
      };
  };
}
