{ den, ... }: {
  den.aspects.browsers = {
    includes = [
      den.aspects.browsers.macos.helium
      den.aspects.browsers.orion
      den.aspects.browsers.zen
    ];
  };
}
