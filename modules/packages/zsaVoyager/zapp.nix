{ den, ... }: {
  den.aspects.zsa.zapp = {
    includes = [
      (den.provides.unfree [ "zapp" ])
    ];

    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        zapp
      ];
    };
  };
}
