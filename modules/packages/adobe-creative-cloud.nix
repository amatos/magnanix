# Aspect:    den.aspects.macos.adobeCreativeCloud
# Platforms: darwin
# Purpose:   Adobe Creative Cloud, the app that signs in to Adobe and installs,
#            updates and licenses Photoshop, Lightroom, Illustrator and the
#            rest, as a Homebrew cask (not packaged in nixpkgs).
#
# Notes:
# - Only the Creative Cloud app is managed here. The Adobe apps it installs are
#   managed by Creative Cloud, not this flake, and it updates itself
#   (the cask is `auto_updates`, so `brew upgrade` leaves it alone).
# - The cask runs Adobe's installer silently with sudo, so the switch that
#   installs it may ask for an admin password.
# - Removing this aspect zaps the cask (homebrew onActivation.cleanup = "zap"),
#   which trashes ~/Creative Cloud Files along with Adobe's settings. Make sure
#   everything there is synced before removing it.
{
  den.aspects.macos.adobeCreativeCloud = {
    darwin = {
      homebrew.casks = [ "adobe-creative-cloud" ];
    };
  };
}
