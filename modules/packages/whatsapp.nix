# Aspect:    den.aspects.whatsapp
# Platforms: darwin, nixos
# Purpose:   WhatsApp: Meta's native app as a Homebrew cask on macOS, and
#            Karere (a GTK4 client wrapping WhatsApp Web) on NixOS.
#
# Notes:
# - Meta doesn't ship a Linux client. nixpkgs dropped wasistlos (formerly
#   whatsapp-for-linux) as unmaintained and points to Karere instead.
# - The `whatsapp` cask is `auto_updates`, so WhatsApp updates itself and
#   `brew upgrade` leaves it alone.
# - Removing this aspect zaps the cask (homebrew onActivation.cleanup = "zap"),
#   which deletes the local chat database; chats come back from the phone after
#   linking again.
{
  den.aspects.whatsapp = {
    darwin = {
      homebrew.casks = [ "whatsapp" ];
    };

    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.karere ];
      };
  };
}
