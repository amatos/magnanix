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
