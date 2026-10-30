# Mac App Store command line interface. macOS only; a no-op on NixOS hosts.
{
  den.aspects.mas = {
    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.mas ];
      };
  };
}
