# CrystalFetch, which builds Windows 11 installer ISOs (for UTM and other VMs).
#
# Installed from the App Store by `brew bundle` through `mas`, which needs you
# signed in to the App Store.
{
  den.aspects.macos.crystalFetch = {
    darwin.homebrew.masApps."CrystalFetch" = 6454431289;
  };
}
