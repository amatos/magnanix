# Aspect:    den.aspects.macos.crystalFetch
# Platforms: darwin
# Purpose:   CrystalFetch, which builds Windows 11 installer ISOs (for UTM and
#            other VMs).
#
# Notes:
# - Installed from the Mac App Store by `brew bundle` through `mas`, so you must
#   be signed in to the App Store.
{
  den.aspects.macos.crystalFetch = {
    darwin.homebrew.masApps."CrystalFetch" = 6454431289;
  };
}
