{
  den.aspects.darwin.screencapture = {
    # A machine-wide default applied to the host's primary user
    # (`system.primaryUser`, set per host via `den.batteries.primary-user`).
    darwin =
      { config, ... }:
      let
        primaryUser = config.system.primaryUser;
        location = "${config.users.users.${primaryUser}.home}/Pictures/Screenshots/unsorted";
      in
      {
        system.defaults.screencapture = {
          inherit location;
          type = "png"; # png, jpg, gif, pdf, tiff
          disable-shadow = true;
          include-date = true;
        };

        # nix-darwin doesn't create the screenshot directory, and macOS ignores a
        # missing location. Create it as the user (activation runs as root).
        system.activationScripts.postActivation.text = ''
          sudo --user=${primaryUser} -- mkdir -p "${location}"
        '';
      };
  };
}
