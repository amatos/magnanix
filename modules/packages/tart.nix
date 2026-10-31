# Tart: macOS/Linux VMs on Apple Silicon. macOS only.
{
  den.aspects.tui.macos.tart = {
    includes = [
      (den.batteries.unfree [
        "tart"
      ])
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.tart ];
      };
  };
}
