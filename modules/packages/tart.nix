# Tart: macOS/Linux VMs on Apple Silicon. macOS only.
{
  den.aspects.tui.macos.tart = {
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.tart ];
      };
  };
}
