# Aspects:   den.aspects.browsers.macos.helium (part of den.aspects.browsers)
#            den.aspects.browsers.linux.helium (opt-in)
# Platforms: darwin (macos.helium); home-manager (linux.helium, x86_64 only)
# Purpose:   Helium, a privacy-focused Chromium browser.
#
# Notes:
# - macOS: Homebrew cask, plus 1Password and the native messaging fix that lets
#   Helium's 1Password extension reach the app (macos._1passwordForHelium).
# - Linux: the upstream AppImage from the AlvaroParker/helium-nix flake. Kept
#   out of the browsers bundle because 1Password integration isn't known to
#   work with it there, so a host has to opt in explicitly.
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
