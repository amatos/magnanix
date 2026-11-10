# Aspect:    den.aspects.nixosKernel (included by base)
# Platforms: nixos
# Purpose:   Kernel and boot appearance: the latest kernel instead of the LTS
#            default (newer hardware support), and a quiet, graphical boot.
#
# Notes:
# - floppy is blacklisted, so the kernel doesn't probe for a floppy controller
#   that none of the machines have.
# - Plymouth shows the "lone" splash theme (adi1090x) during boot, and the
#   kernel and udev only log errors to the console.
{
  den.aspects.nixosKernel = {
    nixos =
      { pkgs, ... }:
      {
        boot.kernelPackages = pkgs.linuxPackages_latest;
        boot.blacklistedKernelModules = [ "floppy" ];

        boot.plymouth = {
          enable = true;
          theme = "lone";
          themePackages = [
            (pkgs.adi1090x-plymouth-themes.override {
              selected_themes = [ "lone" ];
            })
          ];
        };

        # Silent boot
        boot.consoleLogLevel = 3;
        boot.kernelParams = [
          "quiet"
          "udev.log_level=3"
          "systemd.show_status=auto"
        ];
      };
  };
}
