# Aspect:    den.aspects.macos.stecker
# Platforms: darwin
# Purpose:   Stecker, which runs Shortcuts when USB devices are attached or
#            detached.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.stecker = {
    darwin.homebrew.masApps."Stecker" = 6447288587;
  };
}
