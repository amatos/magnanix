# Aspect:    den.aspects.zsa.zapp (part of zsa.voyager)
# Platforms: home-manager
# Purpose:   Zapp (unfree), ZSA's command-line flashing tool for ZSA keyboards.
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
