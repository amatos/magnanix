{
  den.aspects.darwin.screencapture =
    { user, ... }:
    let
      location = "/Users/${user.userName}/Pictures/Screenshots/unsorted";
    in
    {
      darwin = {
        system.defaults.screencapture = {
          inherit location;
          type = "png"; # png, jpg, gif, pdf, tiff
          disable-shadow = true;
          include-date = true;
        };

        # nix-darwin doesn't create the screenshot directory, and macOS ignores a
        # missing location. Create it as the user (activation runs as root).
        system.activationScripts.postActivation.text = ''
          sudo --user=${user.userName} -- mkdir -p "${location}"
        '';
      };
    };
}
