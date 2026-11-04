# Tailscale. On NixOS it's the tailscaled service; on macOS it's the App Store
# app (installed by `brew bundle` through `mas`, which needs you signed in to the
# App Store). Log in to the tailnet by hand after the first switch:
# `sudo tailscale up` on NixOS, the app's menu on macOS.
#
# Hosts on the tailnet send mail through the relay's Tailscale name instead of
# its LAN one (see mail.nix), and reach the Attic cache the same way (see
# attic.nix), so both keep working away from home.
let
  relayHost = "smtp.ts.matos.cc";
  atticHost = "muninn.ts.matos.cc";
in
{
  den.aspects.tailscale = {
    os.local.mail.relayHost = relayHost;
    os.local.attic.serverHost = atticHost;

    nixos.services.tailscale.enable = true;

    darwin.homebrew.masApps.Tailscale = 1475387142;
  };
}
