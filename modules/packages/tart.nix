# Aspect:    den.aspects.tui.macos.tart
# Platforms: darwin
# Purpose:   Tart (unfree), the Apple Virtualization VM manager used by the
#            dev shell's darwintron-vm and nixostron-vm test scripts.
{ den, ... }: {
  den.aspects.tui.macos.tart = {
    includes = [
      (den.batteries.unfree [
        "tart"
      ])
    ];

    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.tart ];
      };
  };
}
