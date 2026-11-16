# Aspect:    den.aspects.macos.alDente
# Platforms: darwin, home-manager (macOS only; does nothing on Linux)
# Purpose:   AlDente by AppHouseKitchen, which limits the MacBook's maximum
#            charge to extend battery life, from nixpkgs (aldente, unfree), with
#            its built-in updater turned off.
#
# Notes:
# - The app lands in /Applications/Nix Apps and is updated with nixpkgs only.
#   Its own updater (Sparkle) is off: nix-darwin copies the store's bundle over
#   /Applications/Nix Apps on every switch, so an in-app update would be
#   reverted silently at the next switch. AlDente Pro's licence is entered in
#   the app.
# - Turning updates off takes three keys. The app's Info.plist enables both
#   automatic checks and silent installs, and user defaults override it. The
#   app also keeps its own `checkForUpdates` key behind the "Allow automatic
#   updates" setting; it is set too so that setting shows off and doesn't turn
#   Sparkle back on.
# - On first launch AlDente asks to install its privileged helper, which it
#   needs to control charging.
{ den, ... }:
{
  den.aspects.macos.alDente = {
    includes = [ (den.batteries.unfree [ "aldente" ]) ];

    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.aldente ];
      };

    homeManager =
      { lib, pkgs, ... }:
      lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        targets.darwin.defaults."com.apphousekitchen.aldente-pro" = {
          # Sparkle: no scheduled checks, no silent installs
          SUEnableAutomaticChecks = false;
          SUAutomaticallyUpdate = false;
          # AlDente's own "Allow automatic updates" setting
          checkForUpdates = false;
        };
      };
  };
}
