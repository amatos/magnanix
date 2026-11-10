# Aspect:    den.aspects.macos.hyperduck
# Platforms: darwin
# Purpose:   Hyperduck, which sends links from iPhone or iPad to the Mac.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.hyperduck = {
    darwin.homebrew.masApps."Hyperduck" = 6444667067;
  };
}
