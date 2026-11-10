# Aspect:    den.aspects.macos._1password
# Platforms: darwin
# Purpose:   Installs the 1Password for Safari extension from the Mac App Store
#            (through `mas`, so you must be signed in to the App Store).
#
# Notes:
# - After the first switch, turn it on in Safari > Settings > Extensions.
# - Named `_1password` because a Nix attribute name can't start with a digit
#   without quoting.
{
  den.aspects.macos._1password = {
    darwin.homebrew.masApps."1Password for Safari" = 1569813296;
  };
}
