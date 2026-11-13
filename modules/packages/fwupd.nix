# Aspect:    den.aspects.cli.fwupd (included by base)
# Platforms: nixos
# Purpose:   fwupd, the firmware update daemon: `fwupdmgr refresh && fwupdmgr
#            update` installs UEFI, SSD and peripheral firmware from LVFS.
{
  den.aspects.cli.fwupd = {
    nixos = {
      services = {
        fwupd = {
          enable = true;
        };
      };
    };
  };
}
