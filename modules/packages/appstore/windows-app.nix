# Aspect:    den.aspects.macos.windowsApp
# Platforms: darwin
# Purpose:   Windows App, Microsoft's remote desktop client.
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.windowsApp = {
    darwin.homebrew.masApps."Windows App" = 1295203466;
  };
}
