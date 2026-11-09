{
  # Sunshine, a game and desktop streaming host for Moonlight clients (NixOS).
  #
  # It runs as a systemd user service started with the graphical session, so it
  # only streams while someone is logged in (fortuna logs alberth in at boot for
  # that). With CAP_SYS_ADMIN it captures the screen through DRM/KMS, which works
  # under any Wayland compositor, and encodes on the GPU through VA-API.
  #
  # Its ports are opened on the Tailscale interface only, so Moonlight connects
  # over the tailnet, by the host's Tailscale name or IP (mDNS discovery doesn't
  # cross Tailscale, so add the host by hand in Moonlight).
  #
  # First setup, after the first switch:
  #   1. set the web UI's username and password, either in the web UI itself
  #      (https://localhost:47990, from the host; it asks for them on first visit)
  #      or with `sunshine --creds <username> <password>`
  #   2. add the host in Moonlight; it shows a PIN, which you enter in the web
  #      UI's PIN page (https://<host>:47990/pin) to pair
  #
  # Apps are left to Sunshine's defaults (Desktop and Steam Big Picture), so they
  # stay editable from the web UI: setting services.sunshine.applications would
  # make Sunshine read a read-only config file from the store instead.
  #
  # KMS capture needs an active display. With the monitor off or unplugged,
  # use a dummy HDMI/DisplayPort plug or an EDID override (drm.edid_firmware).
  den.aspects.sunshine = {
    nixos =
      { config, ... }:
      let
        port = config.services.sunshine.settings.port; # 47989 by default
        # The same offsets from the base port that services.sunshine.openFirewall uses.
        ports = map (offset: port + offset);
      in
      {
        services.sunshine = {
          enable = true;
          autoStart = true;
          capSysAdmin = true;
        };

        networking.firewall.interfaces.${config.services.tailscale.interfaceName} = {
          # 47984 (HTTPS), 47989 (HTTP), 47990 (web UI), 48010 (RTSP)
          allowedTCPPorts = ports [
            (-5)
            0
            1
            21
          ];
          # 47998 (video), 47999 (control), 48000 (audio), 48002 (mic), 48010 (RTSP)
          allowedUDPPorts = ports [
            9
            10
            11
            13
            21
          ];
        };
      };
  };
}
