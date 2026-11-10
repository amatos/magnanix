# Aspect:    den.aspects.macos.cleanShot
# Platforms: darwin
# Purpose:   CleanShot X, the screenshot and screen-recording tool, as a Homebrew
#            cask. It isn't in nixpkgs or the App Store; the license is bought
#            from cleanshot.com. Needs macOS 13 or newer.
{
  den.aspects.macos.cleanShot = {
    darwin = {
      homebrew.casks = [ "cleanshot" ];
    };
  };
}
