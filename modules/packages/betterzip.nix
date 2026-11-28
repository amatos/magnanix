# Aspect:    den.aspects.macos.betterZip
# Platforms: darwin
# Purpose:   BetterZip, an archive utility for creating, browsing and
#            extracting archives, as a Homebrew cask.
#
# Notes:
# - The `betterzip` cask is `auto_updates`, so BetterZip updates itself and
#   `brew upgrade` leaves it alone.
# - The cask also links the `betterzip` command-line tool into Homebrew's bin.
{
  den.aspects.macos.betterZip = {
    darwin = {
      homebrew.casks = [ "betterzip" ];
    };
  };
}
