# Aspect:    den.aspects.darwin.customizations (included by base)
# Platforms: darwin (the darwin class is ignored on NixOS hosts)
# Purpose:   Bundles the macOS System Settings aspects in this directory, one
#            per settings area, so every macOS host gets them.
#
# Notes:
# - The Dock is not here: it follows a user (modules/users/<user>/dock.nix),
#   so machines without that user keep the stock Dock.
{ den, ... }: {
  den.aspects.darwin.customizations = {
    includes = [
      den.aspects.darwin.controlCenter
      den.aspects.darwin.finder
      den.aspects.darwin.menuExtraClock
      den.aspects.darwin.nsGlobalDomain
      den.aspects.darwin.screencapture
      den.aspects.darwin.softwareUpdate
      den.aspects.darwin.loginWindow
      den.aspects.darwin.screenSaver
      den.aspects.darwin.trackpad
    ];

  };
}
