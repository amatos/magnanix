{
  # UEFI boot via systemd-boot, for NixOS hosts whose ESP is mounted at /boot.
  den.aspects.systemdBoot = {
    nixos = {
      boot = {
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };

        # Mount /tmp as a tmpfs and clear it on every boot
        tmp = {
          cleanOnBoot = true;
          useTmpfs = true;
        };
      };
    };
  };
}
