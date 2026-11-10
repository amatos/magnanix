# Aspect:    den.aspects.macos.hyperspace
# Platforms: darwin
# Purpose:   Hyperspace, which reclaims disk space taken by duplicate files.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.hyperspace = {
    darwin.homebrew.masApps."Hyperspace" = 6739505345;
  };
}
