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
