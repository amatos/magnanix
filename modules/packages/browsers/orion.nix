# Aspect:    den.aspects.browsers.macos.orion (part of den.aspects.browsers)
# Platforms: home-manager (macOS only)
# Purpose:   Orion, Kagi's WebKit browser, from nixpkgs (unfree), plus the
#            1Password app. It lands in ~/Applications/Home Manager Apps.
{ den, ... }: {
  den.aspects.browsers.macos.orion = {
    includes = [
      den.aspects._1password
      (den.batteries.unfree [ "orion-browser" ])
    ];

    homeManager = { pkgs, lib, ... }: {
      home.packages = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        pkgs.orion-browser
      ];
    };
  };
}
