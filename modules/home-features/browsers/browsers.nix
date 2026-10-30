{ den, ... }: {
  den.aspects.browsers = {
    includes = [
      den.aspects.browsers.helium
      den.aspects.browsers.orion
      den.aspects.browsers.zen
    ];
  };
}
