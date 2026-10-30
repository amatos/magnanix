{
  den.aspects.darwin.nsGlobalDomain = {
    darwin.system.defaults.NSGlobalDomain = {
      # ==========================================================================
      # Key Repeat
      # ==========================================================================

      # Delay before key repeat starts (lower = faster)
      # Default: 68 (about 1.02 seconds)
      # Units of 15ms: 25 = ~375ms, 15 = ~225ms
      InitialKeyRepeat = 68;

      # Key repeat rate once started (lower = faster)
      # Default: 6 (about 90ms between repeats)
      # 2 = fastest, 1 = even faster (may cause issues)
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
      AppleInterfaceStyle = null;
      AppleInterfaceStyleSwitchesAutomatically = true;
      AppleShowScrollBars = "Automatic";

      # Text & Typing
      NSAutomaticCapitalizationEnabled = true;
      NSAutomaticDashSubstitutionEnabled = true;
      NSAutomaticPeriodSubstitutionEnabled = true;
      NSAutomaticQuoteSubstitutionEnabled = true;
      NSAutomaticSpellingCorrectionEnabled = true;
      NSAutomaticInlinePredictionEnabled = true;

      # Windows & Dialogs
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
      NSDocumentSaveNewDocumentsToCloud = true;

      # Animations
      NSAutomaticWindowAnimationsEnabled = true;
      NSScrollAnimationEnabled = true;
      NSUseAnimatedFocusRing = true;

      # Finder Sidebar - Icon size: 1=small, 2=medium, 3=large
      NSTableViewDefaultSizeMode = 3;

      # Language & Region - Imperial system
      AppleTemperatureUnit = "Fahrenheit";
      AppleMeasurementUnits = "Inches";
      AppleMetricUnits = 0;
      AppleICUForce24HourTime = true;

    };
  };
}
