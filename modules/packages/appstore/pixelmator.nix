# Aspect:    den.aspects.macos.pixelmator
# Platforms: darwin
# Purpose:   Pixelmator Pro (image editor) and Photomator (photo editor).
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.pixelmator = {
    darwin.homebrew.masApps = {
      "Pixelmator Pro" = 6746662575;
      "Photomator" = 1444636541;
    };
  };
}
