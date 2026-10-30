{ den, ... }: {
  den.aspects.browsers.orion = {
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
