# Aspect:    den.aspects.macos.harbor
# Platforms: darwin
# Purpose:   Harbor, a native download manager for direct links, magnets and
#            torrents, as a Homebrew cask. Not in nixpkgs or homebrew-cask; it
#            comes from the developer's own tap (thsnkhn/harbor).
#
# Notes:
# - The tap is declared here because homebrew.onActivation.cleanup = "zap"
#   also untaps anything not declared in the flake.
{
  den.aspects.macos.harbor = {
    darwin = {
      homebrew.taps = [ "thsnkhn/harbor" ];
      homebrew.casks = [ "thsnkhn/harbor/harbor" ];
    };
  };
}
