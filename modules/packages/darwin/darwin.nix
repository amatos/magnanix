{ den, ... }: {
  # macOS system defaults, included in every host through `den.aspects.base`
  # (the `darwin` class is ignored on NixOS hosts).
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
