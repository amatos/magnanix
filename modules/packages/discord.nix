# Aspect:    den.aspects.macos.discord
# Platforms: darwin
# Purpose:   Discord's native macOS client as a Homebrew cask.
#
# Notes:
# - The `discord` cask is `auto_updates`, so Discord updates itself and
#   `brew upgrade` leaves it alone.
{
  den.aspects.macos.discord = {
    darwin = {
      homebrew.casks = [ "discord" ];
    };
  };
}
