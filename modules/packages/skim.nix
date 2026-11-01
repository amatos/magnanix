{
  den.aspects.macos.skim = {
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.skimpdf ];
      };
  };
}
