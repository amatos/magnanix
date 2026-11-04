# The 1Password for Safari extension, as the App Store app (installed by
# `brew bundle` through `mas`, which needs you signed in to the App Store).
# Turn it on in Safari > Settings > Extensions after the first switch.
#
# `macos._1password` rather than `macos.1password`: a Nix attribute name can't
# start with a digit without quoting, the same reason the main aspect is
# `_1password`.
{
  den.aspects.macos._1password = {
    darwin.homebrew.masApps."1Password for Safari" = 1569813296;
  };
}
