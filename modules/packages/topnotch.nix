# Aspect:    den.aspects.macos.topNotch
# Platforms: darwin
# Purpose:   TopNotch, which hides the MacBook notch behind a black menu bar, as
#            a Homebrew cask. Free; not in nixpkgs or the App Store.
{
  den.aspects.macos.topNotch = {
    darwin = {
      homebrew.casks = [ "topnotch" ];
    };
  };
}
