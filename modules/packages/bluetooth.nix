# Aspect:    den.aspects.bluetooth
# Platforms: nixos
# Purpose:   Enables Bluetooth (BlueZ), with its experimental features so device
#            battery levels are reported to the desktop.
{
  den.aspects.bluetooth = {
    nixos = {
      hardware.bluetooth = {
        enable = true;

        # BlueZ's experimental features, chiefly reporting the battery level of
        # headsets and other devices to the system.
        settings.General.Experimental = true;
      };
    };
  };
}
