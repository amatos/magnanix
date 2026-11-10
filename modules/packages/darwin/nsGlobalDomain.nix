# Aspect:    den.aspects.darwin.nsGlobalDomain (part of darwin.customizations)
# Platforms: darwin
# Purpose:   System-wide (NSGlobalDomain) preferences: keyboard, text input,
#            appearance, save/print dialogs, animations, units and clock.
#
# Notes (changes from macOS defaults):
# - Full keyboard access: Tab moves focus between all controls.
# - Appearance follows the time of day (automatic light/dark).
# - Save and Print dialogs open expanded.
# - Large sidebar icons (NSTableViewDefaultSizeMode = 3).
# - Imperial units (Fahrenheit, inches) with a 24-hour clock.
# - Text substitutions and animations are set to their defaults explicitly, so a
#   change made in System Settings is reset on the next switch.
{
  den.aspects.darwin.nsGlobalDomain = {
    darwin.system.defaults.NSGlobalDomain = {
      # ==========================================================================
      # Key Repeat
      # ==========================================================================

      # Both values are in units of ~15 ms. System Settings > Keyboard only offers
      # slider notches (Delay Until Repeat: 15 = shortest; Key Repeat Rate:
      # 2 = fastest); lower values can only be set here. Apple's stock values
      # vary between macOS versions; check with `defaults read -g InitialKeyRepeat`.

      # How long a key must be held before it starts repeating (lower = sooner).
      # 68 x 15 ms = ~1 s.
      InitialKeyRepeat = 68;

      # Time between repeats once repeating (lower = faster).
      # 6 x 15 ms = ~90 ms, about 11 characters per second.
      KeyRepeat = 6;

      # ==========================================================================
      # Keyboard Navigation
      # ==========================================================================

      # Full keyboard access for all controls
      # 0 = Text boxes and lists only
      # 2 = All controls (Tab moves focus)
      # 3 = All controls (includes Esc to close dialogs)
      AppleKeyboardUIMode = 3;

      # false = F1-F12 trigger their special functions (brightness, volume, ...);
      #          hold Fn to get the plain function key
      # true  = F1-F12 are standard function keys; hold Fn for special functions
      # Default: false
      "com.apple.keyboard.fnState" = false;

      # ==========================================================================
      # Text Input
      # ==========================================================================

      # true  = holding a key shows the accented-character popup
      # false = holding a key repeats it instead
      # Default: true
      ApplePressAndHoldEnabled = true;

      # ==========================================================================
      # System UI
      # ==========================================================================

      # Light/dark mode: no fixed style, switch automatically with the time of day
      # (System Settings > Appearance > Auto).
      AppleInterfaceStyle = null;
      AppleInterfaceStyleSwitchesAutomatically = true;
      # Scroll bars appear based on the input device (macOS default).
      AppleShowScrollBars = "Automatic";

      # Text & Typing: all of macOS's automatic corrections stay on (defaults).
      NSAutomaticCapitalizationEnabled = true;
      NSAutomaticDashSubstitutionEnabled = true;
      NSAutomaticPeriodSubstitutionEnabled = true;
      NSAutomaticQuoteSubstitutionEnabled = true;
      NSAutomaticSpellingCorrectionEnabled = true;
      NSAutomaticInlinePredictionEnabled = true;

      # Windows & Dialogs: open Save and Print dialogs expanded, showing every
      # option, instead of the compact form. New documents save to iCloud.
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
      NSDocumentSaveNewDocumentsToCloud = true;

      # Animations (macOS defaults)
      NSAutomaticWindowAnimationsEnabled = true;
      NSScrollAnimationEnabled = true;
      NSUseAnimatedFocusRing = true;

      # Finder Sidebar - Icon size: 1=small, 2=medium, 3=large
      NSTableViewDefaultSizeMode = 3;

      # Language & Region: imperial units, but a 24-hour clock everywhere
      # (the menu bar clock's format is in menuExtraClock.nix).
      AppleTemperatureUnit = "Fahrenheit";
      AppleMeasurementUnits = "Inches";
      AppleMetricUnits = 0;
      AppleICUForce24HourTime = true;

    };
  };
}
