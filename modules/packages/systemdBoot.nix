# Aspect:    den.aspects.systemdBoot (included by base)
# Platforms: nixos
# Purpose:   UEFI boot with systemd-boot, and /tmp as a tmpfs cleared on boot.
#
# Notes:
# - The EFI system partition must be mounted at /boot.
# - canTouchEfiVariables lets nixos-rebuild register the boot entry in the
#   firmware's NVRAM.
{
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
