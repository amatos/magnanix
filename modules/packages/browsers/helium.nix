{ den, inputs, ... }: {
  flake-file.inputs.helium = {
    url = "github:AlvaroParker/helium-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

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

  # The upstream AppImage, wrapped by a community flake (x86_64 only). Not part
  # of the browsers aspect: 1Password's browser integration isn't known to work
  # with Helium on Linux, so hosts opt in individually.
  den.aspects.browsers.linux.helium.homeManager = { pkgs, ... }: {
    home.packages = [ inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  };
}
