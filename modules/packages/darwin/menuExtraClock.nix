# Aspect:    den.aspects.darwin.menuExtraClock (part of darwin.customizations)
# Platforms: darwin
# Purpose:   The menu bar clock, shown as an ISO-style "yyyy-MM-dd HH:mm:ss"
#            24-hour timestamp with the day of the week.
#
# Notes:
# - menuExtraClock picks WHICH parts show; the custom DateFormat in
#   CustomUserPreferences decides HOW they are formatted and overrides it.
{
  den.aspects.darwin.menuExtraClock = {
    darwin.system.defaults = {
      menuExtraClock = {
        ShowDate = 0; # 0 = When space allows, 1 = Always, 2 = Never
        ShowDayOfWeek = true;
        ShowSeconds = false; # No effect while the custom DateFormat below is set (it includes :ss)
        Show24Hour = true; # Also set via AppleICUForce24HourTime
        IsAnalog = false; # false = digital, true = analog
      };
      # --- Custom User Preferences ---
      # Settings not exposed as first-class nix-darwin options
      CustomUserPreferences = {
        "com.apple.menuextra.clock" = {
          # Custom date/time format (overrides menuExtraClock display settings)
          # menuExtraClock controls WHICH elements show; DateFormat controls HOW they display
          DateFormat = "yyyy-MM-dd HH:mm:ss"; # ISO 8601-like format (space separator)
          FlashDateSeparators = false; # Don't blink separators
        };
      };
    };
  };
}
