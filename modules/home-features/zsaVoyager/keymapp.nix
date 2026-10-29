{ den, ... }: {
  den.aspects.zsa.keymapp = {
    includes = [
      (den.provides.unfree [ "keymapp"])
    ];

    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        keymapp
      ];
    };
  };
}
