# Aspect:    den.aspects.tailscale
# Platforms: nixos, darwin
# Purpose:   Tailscale: tailscaled on NixOS, the App Store app on macOS (through
#            `mas`, so you must be signed in to the App Store).
#
# Notes:
# - Log in once after the first switch: `sudo tailscale up` on NixOS, the menu
#   bar app on macOS.
# - The App Store app doesn't put a CLI on PATH, but its binary acts as one when
#   run from a terminal, so a `tailscale` wrapper execs it.
# - Hosts with this aspect reach the mail relay and the Attic cache by their
#   Tailscale names (smtp.ts / muninn.ts) instead of the LAN ones, so both keep
#   working away from home.
let
  relayHost = "smtp.ts.matos.cc";
  atticHost = "muninn.ts.matos.cc";
in
{
  den.aspects.tailscale = {
    os.local.mail.relayHost = relayHost;
    os.local.attic.serverHost = atticHost;

    nixos.services.tailscale.enable = true;

    darwin =
      { pkgs, ... }:
      {
        homebrew.masApps.Tailscale = 1475387142;

        environment.systemPackages = [
          (pkgs.writeShellScriptBin "tailscale" ''
            exec /Applications/Tailscale.app/Contents/MacOS/Tailscale "$@"
          '')
        ];
      };
  };
}
