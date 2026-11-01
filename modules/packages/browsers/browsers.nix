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
