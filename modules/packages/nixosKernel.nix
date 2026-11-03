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
