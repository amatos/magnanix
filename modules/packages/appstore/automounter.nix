# Aspect:    den.aspects.macos.autoMounter
# Platforms: darwin
# Purpose:   AutoMounter, which keeps network shares mounted.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.autoMounter = {
    darwin.homebrew.masApps."AutoMounter" = 1160435653;
  };
}
