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
