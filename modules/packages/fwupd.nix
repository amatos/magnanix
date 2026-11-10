# Aspect:    den.aspects.fwupd (included by base)
# Platforms: nixos
# Purpose:   fwupd, the firmware update daemon: `fwupdmgr refresh && fwupdmgr
#            update` installs UEFI, SSD and peripheral firmware from LVFS.
{
  den.aspects.fwupd = {
    nixos = {
      services = {
        fwupd = {
          enable = true;
        };
      };
    };
  };
}
