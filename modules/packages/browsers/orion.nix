{ den, ... }: {
  den.aspects.browsers.macos.orion = {
    includes = [
      (den.batteries.unfree [ "orion-browser" ])
    ];

    homeManager = { pkgs, lib, ... }: {
      home.packages = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        pkgs.orion-browser
      ];
    };
  };
}
