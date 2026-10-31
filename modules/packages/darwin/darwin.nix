{ den, ... }: {
  den.aspects.alberth.darwinCustomizations = {
    includes = [
      den.aspects.darwin.controlCenter
      den.aspects.darwin.dock
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
