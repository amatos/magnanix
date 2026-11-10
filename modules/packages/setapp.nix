# Aspect:    den.aspects.macos.setapp
# Platforms: darwin
# Purpose:   Setapp, the subscription app store for Mac apps, as a Homebrew cask.
#            Apps installed through Setapp are managed by Setapp, not this flake.
{
  den.aspects.macos.setapp = {
    darwin = {
      homebrew.casks = [ "setapp" ];
    };
  };
}
