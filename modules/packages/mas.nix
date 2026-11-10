# Aspect:    den.aspects.macos.mas
# Platforms: home-manager (macOS only; installs nothing on Linux)
# Purpose:   `mas`, the Mac App Store command line interface, for searching and
#            installing App Store apps by hand (`mas search`, `mas install`).
{
  den.aspects.macos.mas = {
    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.mas ];
      };
  };
}
