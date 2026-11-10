# Aspect:    den.aspects.darwin.controlCenter (part of darwin.customizations)
# Platforms: darwin
# Purpose:   Chooses which Control Center modules appear in the menu bar
#            (System Settings > Control Center).
#
# Notes:
# - Shown: Bluetooth, Sound, Focus and Now Playing. Hidden: Display, and the
#   battery percentage next to the battery icon.
{
  den.aspects.darwin.controlCenter = {
    darwin.system.defaults.controlcenter = {
      # true = show the module's icon in the menu bar, false = hide it, null
      # (unset) = leave macOS's own choice.
      BatteryShowPercentage = false; # battery icon only, no percentage text
      Bluetooth = true;
      Sound = true;
      Display = false;
      FocusModes = true;
      NowPlaying = true;
    };
  };
}
