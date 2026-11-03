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
