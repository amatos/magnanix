# Aspect:    den.aspects.darwin.softwareUpdate (part of darwin.customizations)
# Platforms: darwin
# Purpose:   Installs macOS updates automatically.
{
  den.aspects.darwin.softwareUpdate = {
    darwin.system.defaults = {
      SoftwareUpdate = {
        AutomaticallyInstallMacOSUpdates = true;
      };
    };
  };
}
