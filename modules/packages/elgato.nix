# Aspect:    den.aspects.elgato
# Platforms: darwin, nixos
# Purpose:   Elgato device software: Elgato's own apps as casks on macOS, and
#            open-source stand-ins on NixOS (Elgato doesn't support Linux).
#
# Notes:
# - NixOS: streamdeck-ui is installed for its udev rules (device access for the
#   logged-in user) but not autostarted, because a background instance would
#   hold the Stream Deck and lock Boatswain out. Use Boatswain for the Stream
#   Deck and keylight-cli / Keylight Controller for Key Lights.
# - Nothing on NixOS replaces the capture device utility, Studio or Wave Link.
{
  den.aspects.elgato = {
    # Elgato's own apps are macOS/Windows only and not in nixpkgs.
    darwin.homebrew.casks = [
      "elgato-capture-device-utility"
      "elgato-control-center"
      "elgato-stream-deck"
      "elgato-studio"
      "elgato-wave-link"
    ];

    # Open-source stand-ins on NixOS. There is nothing for the capture devices,
    # Elgato Studio or Wave Link.
    nixos =
      { pkgs, ... }:
      {
        # Installs streamdeck-ui and its udev rules, which give the logged-in user
        # access to Stream Decks (Boatswain relies on them too). Not autostarted:
        # the background instance would hold the device and lock Boatswain out.
        programs.streamdeck-ui = {
          enable = true;
          autoStart = false;
        };

        environment.systemPackages = with pkgs; [
          # Stream Deck (GNOME/libadwaita)
          boatswain
          # Key Lights
          keylight-cli
          keylight-controller-mschneider82
        ];
      };
  };
}
