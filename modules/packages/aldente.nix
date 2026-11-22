# Aspect:    den.aspects.macos.alDente
# Platforms: darwin
# Purpose:   AlDente by AppHouseKitchen, which limits the MacBook's maximum
#            charge to extend battery life, as a Homebrew cask.
#
# Notes:
# - The `aldente` cask is `auto_updates`, so AlDente updates itself through
#   its built-in updater (Sparkle) and `brew upgrade` leaves it alone. AlDente
#   Pro's licence is entered in the app.
# - On first launch AlDente asks to install its privileged helper, which it
#   needs to control charging.
# - Removing this aspect zaps the cask (homebrew onActivation.cleanup = "zap"),
#   which removes the helper and trashes AlDente's preferences and statistics.
{
  den.aspects.macos.alDente = {
    darwin = {
      homebrew.casks = [ "aldente" ];
    };
  };
}
