{ den, ... }: {
  den.aspects.browsers = {
    includes = [
      den.aspects.browsers.firefox
      den.aspects.browsers.macos.helium
      den.aspects.browsers.orion
      den.aspects.browsers.zen
    ];
  };
}
