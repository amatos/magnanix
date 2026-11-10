# Aspect:    den.aspects.zsa.keymapp (part of zsa.voyager)
# Platforms: home-manager
# Purpose:   Keymapp (unfree), ZSA's app for flashing firmware to ZSA keyboards
#            and showing the live layout.
{ den, ... }: {
  den.aspects.zsa.keymapp = {
    includes = [
      (den.provides.unfree [ "keymapp" ])
    ];

    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        keymapp
      ];
    };
  };
}
