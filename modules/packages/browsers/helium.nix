{ den, ... }: {
  den.aspects.browsers.macos.helium = {
    # The 1Password app, plus the native messaging host Helium needs to reach it.
    includes = [
      den.aspects._1password
      den.aspects.macos._1passwordForHelium
    ];

    darwin = {
      homebrew.casks = [ "helium-browser" ];
    };
  };
}
