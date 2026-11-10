# Aspect:    den.aspects.browsers
# Platforms: darwin, home-manager (through the aspects it includes)
# Purpose:   The browser bundle: Firefox, Helium (macOS), Orion (macOS) and Zen,
#            each set up to work with 1Password. Helium on Linux is a separate,
#            opt-in aspect (browsers.linux.helium).
{ den, ... }: {
  den.aspects.browsers = {
    includes = [
      den.aspects.browsers.firefox
      den.aspects.browsers.macos.helium
      den.aspects.browsers.macos.orion
      den.aspects.browsers.zen
    ];
  };
}
