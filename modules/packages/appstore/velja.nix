# Aspect:    den.aspects.macos.velja
# Platforms: darwin
# Purpose:   Velja browser picker (used by `~/.local/bin/velja-open.sh`).
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.velja = {
    darwin.homebrew.masApps."Velja" = 1607635845;
  };
}
