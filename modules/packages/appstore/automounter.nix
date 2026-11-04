# AutoMounter, which keeps network shares mounted.
#
# Installed from the App Store by `brew bundle` through `mas`, which needs you
# signed in to the App Store.
{
  den.aspects.macos.autoMounter = {
    darwin.homebrew.masApps."AutoMounter" = 1160435653;
  };
}
