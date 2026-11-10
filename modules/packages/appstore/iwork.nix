# Aspect:    den.aspects.macos.iwork
# Platforms: darwin
# Purpose:   Apple's iWork apps: Pages, Keynote and Numbers.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.iwork = {
    darwin.homebrew.masApps = {
      "Pages" = 361309726;
      "Keynote" = 361285480;
      "Numbers" = 361304891;
    };
  };
}
