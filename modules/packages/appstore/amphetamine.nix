# Aspect:    den.aspects.macos.amphetamine
# Platforms: darwin
# Purpose:   Amphetamine, which keeps the Mac awake.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.amphetamine = {
    darwin.homebrew.masApps."Amphetamine" = 937984704;
  };
}
