# User:      alberth (den.aspects.alberth.macos.dock)
# Platforms: darwin
# Purpose:   alberth's Dock: appearance, behaviour, gestures, hot corners and
#            the declarative list of Dock apps and folders.
#
# Notes:
# - nix-darwin applies Dock settings to the host's primary user
#   (system.primaryUser), so this only makes sense where that is alberth. It
#   lives with the user rather than in darwin.customizations so machines
#   without alberth keep the stock Dock.
# - persistent-apps / persistent-others are declarative: manual Dock changes are
#   overwritten on the next switch. Add apps here instead.
# - Changes from macOS defaults: autohide on with a shorter delay, hidden apps'
#   icons translucent, all hot corners disabled, spring loading on all items,
#   hover highlight in stack grid view.
{
  den.aspects.alberth.macos.dock = {
    # alberth's Dock. nix-darwin applies it to the host's primary user
    # (`system.primaryUser`, set per host via `den.batteries.primary-user`), so
    # this only makes sense on hosts where that is alberth.
    darwin =
      { config, ... }:
      let
        home = config.users.users.${config.system.primaryUser}.home;
      in
      {
        system.defaults = {
          dock = {
            # ==========================================================================
            # Dock Appearance
            # ==========================================================================

            # Size of dock icons (in pixels)
            # Default: 64
            tilesize = 64;

            # Enable icon magnification on hover
            # Default: false
            magnification = false;

            # Magnified icon size (16-128 pixels)
            # Default: 128
            largesize = 128;

            # Dock position on screen: "bottom", "left", or "right"
            # Default: "bottom"
            orientation = "bottom";

            # ==========================================================================
            # Dock Behavior
            # ==========================================================================

            # Automatically hide and show the Dock
            # Default: false
            autohide = true;

            # Delay before Dock shows when hidden (seconds)
            # macOS default: 0.5 (0.24 is a snappier custom value)
            # Only applies when autohide = true
            autohide-delay = 0.24;

            # Animation speed for hide/show (seconds)
            # macOS default: 0.5 (1.0 = slower than default)
            # Lower = faster animation
            autohide-time-modifier = 1.0;

            # Animate opening applications (bounce effect)
            # Default: true
            launchanim = true;

            # Show indicator dots for running applications
            # Default: true
            show-process-indicators = true;

            # Show recent applications section in Dock
            # Default: true
            # Enabled: allows temporary/non-Nix-managed apps to appear on the right
            # side of the dock without polluting the persistent-apps list. Recent
            # apps rotate automatically, keeping the dock clean.
            show-recents = true;

            # Minimize windows into their application icon
            # Default: false
            minimize-to-application = false;

            # Window minimize animation: "genie", "suck", or "scale"
            # Default: "genie"
            mineffect = "genie";

            # Make icons of hidden apps translucent
            # Default: false
            showhidden = true;

            # Show only open applications (hide persistent apps)
            # Default: false
            static-only = false;

            # ==========================================================================
            # Spaces & Mission Control
            # ==========================================================================

            # Automatically rearrange Spaces based on most recent use
            # Default: true
            # false = keep spaces in fixed order
            mru-spaces = true;

            # Group windows by application in Mission Control
            # Default: true
            expose-group-apps = true;

            # Mission Control animation duration (seconds)
            # Default: not set (uses system default)
            # expose-animation-duration = 0.15;

            # ==========================================================================
            # Trackpad Gestures (Dock-related)
            # ==========================================================================

            # Four-finger spread to show Desktop
            showDesktopGestureEnabled = true;

            # Four-finger pinch to show Launchpad
            showLaunchpadGestureEnabled = true;

            # Three-finger swipe up for Mission Control
            showMissionControlGestureEnabled = true;

            # Three-finger swipe down for App Exposé
            showAppExposeGestureEnabled = true;

            # ==========================================================================
            # Hot Corners
            # ==========================================================================
            #
            # Action values:
            #   1  = Disabled
            #   2  = Mission Control
            #   3  = Application Windows (App Exposé)
            #   4  = Desktop
            #   5  = Start Screen Saver
            #   6  = Disable Screen Saver
            #   10 = Put Display to Sleep
            #   11 = Launchpad
            #   12 = Notification Center
            #   13 = Lock Screen
            #   14 = Quick Note
            #
            # Current configuration: all hot corners disabled.

            # Top-left corner
            wvous-tl-corner = 1;

            # Top-right corner
            wvous-tr-corner = 1;

            # Bottom-left corner
            wvous-bl-corner = 1;

            # Bottom-right corner
            wvous-br-corner = 1;

            # ==========================================================================
            # Advanced Options
            # ==========================================================================

            # Display app switcher on all displays
            # Default: false (only main display)
            # appswitcher-all-displays = false;

            # Scroll up on Dock icon to show all windows in that Space
            # Default: true
            scroll-to-open = true;

            # Spring loading for Dock items (drag files over apps)
            # Default: false
            enable-spring-load-actions-on-all-items = true;

            # Highlight hover effect for stack grid view
            # Default: false
            mouse-over-hilite-stack = true;

            # Hold Shift for slow-motion minimize animation
            # Default: false
            # slow-motion-allowed = false;

            # Dock Persistent Apps
            #
            # Apps appear in the Dock in this exact order.
            # Manual Dock changes WILL BE OVERWRITTEN on rebuild.
            #
            # App locations:
            #   - System apps: /System/Applications/
            #   - Nix system packages: /Applications/Nix Apps/
            #   - Home Manager apps (copyApps): ~/Applications/Home Manager Apps/
            #   - Homebrew casks and manual installs: /Applications/
            #   - User apps: ~/Applications/
            #
            # Here: Orion comes from Home Manager (copyApps); Helium, Zed, Delta and
            # Claude are Homebrew casks.

            # ========================================================================
            # Left side of Dock (before separator) - Main apps
            # ========================================================================
            persistent-apps = [
              "/System/Applications/Apps.app"
              "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
              "${home}/Applications/Home Manager Apps/Orion.app"
              "/Applications/Helium.app"
              "/System/Applications/Messages.app"
              "/System/Applications/Mail.app"
              "/System/Applications/Maps.app"
              "/System/Applications/FaceTime.app"
              "/System/Applications/Phone.app"
              "/System/Applications/Calendar.app"
              "/System/Applications/Contacts.app"
              "/System/Applications/Reminders.app"
              "/System/Applications/Notes.app"
              "/System/Applications/Photos.app"
              "/System/Applications/TV.app"
              "/System/Applications/Music.app"
              "/System/Applications/Games.app"
              "/System/Applications/App Store.app"
              "/System/Applications/iPhone Mirroring.app"
              "/System/Applications/System Settings.app"
              "/System/Applications/Preview.app"
              "/Applications/iTerm.app"
              "${home}/Applications/Home Manager Apps/Ghostty.app"
              "/Applications/Zed.app"
              "/Applications/Delta.app"
              "/Applications/Claude.app"
            ];

            # ========================================================================
            # Right side of Dock (after separator) - Folders & utilities
            # ========================================================================
            persistent-others = [
              # {
              #   folder = {
              #     path = "/Volumes";
              #     showas = "automatic";
              #     displayas = "folder";
              #     arrangement = "name";
              #   };
              # }
              {
                folder = {
                  path = "${home}/Downloads";
                  showas = "fan";
                  displayas = "stack";
                  arrangement = "date-modified";
                };
              }
            ];
          };
        };
      };
  };
}
