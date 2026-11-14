# Aspects:   den.aspects.ntp.client (included by base, so every host)
#            den.aspects.ntp.server (opt-in; the LAN and tailnet's time server)
# Platforms: client: nixos, darwin; server: nixos
# Purpose:   Network time from the network's own NTP server, muninn.
#            - client: syncs the clock from `local.ntp.serverHost`
#              (muninn.home.matos.cc by default; the `tailscale` aspect switches
#              it to muninn.ts.matos.cc), falling back to public servers when it
#              can't be reached (muninn down, away without Tailscale).
#            - server: runs chrony, syncing from public servers and answering
#              NTP requests from the LAN and the tailnet on UDP 123.
#
# Notes:
# - NixOS clients use systemd-timesyncd with `networking.timeServers`: the LAN
#   server first, then `local.ntp.upstreamServers`. timesyncd talks to one
#   server at a time and moves down the list when one stops answering.
# - macOS clients: nix-darwin has no time server option, so activation writes
#   /etc/ntp.conf (what System Settings > General > Date & Time edits) with the
#   LAN server first and time.apple.com after it, then restarts timed.
# - The server's port is opened only on the interfaces in
#   local.ntp.server.interfaces, and chrony answers only `ntpClients`.
# - A host whose name lookups depend on the clock (tenabrae) sets
#   `local.ntp.serverHost` to muninn's address instead of its name.
#
# Test: `chronyc tracking` and `chronyc clients` on the server; on a NixOS
# client, `timedatectl timesync-status`; from a Mac, `sntp muninn.home.matos.cc`.
let
  lanHost = "muninn.home.matos.cc";
  port = 123;

  # Clients the server answers: the LAN and the tailnet.
  ntpClients = [
    "10.0.4.0/22"
    "100.64.0.0/10" # Tailscale IPv4
    "fd7a:115c:a1e0::/48" # Tailscale IPv6
  ];

  # macOS's own default, kept as the Mac's fallback.
  appleTimeServer = "time.apple.com";
in
{
  den.aspects.ntp.client = {
    os =
      { lib, ... }:
      {
        options.local.ntp.serverHost = lib.mkOption {
          type = lib.types.str;
          default = lanHost;
          description = "The network's NTP server (muninn), tried before any public server.";
        };
      };

    nixos =
      { config, lib, ... }:
      {
        options.local.ntp.upstreamServers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "0.nixos.pool.ntp.org"
            "1.nixos.pool.ntp.org"
            "2.nixos.pool.ntp.org"
            "3.nixos.pool.ntp.org"
          ];
          description = "Public NTP servers: the fallback after `local.ntp.serverHost` on clients, and what the LAN server itself syncs from.";
        };

        config.networking.timeServers = [
          config.local.ntp.serverHost
        ]
        ++ config.local.ntp.upstreamServers;
      };

    darwin =
      { config, lib, ... }:
      let
        ntpConf = lib.concatMapStrings (server: "server ${server}\n") [
          config.local.ntp.serverHost
          appleTimeServer
        ];
      in
      {
        # Rewrite the file only when it changes, so timed isn't restarted on every
        # switch.
        system.activationScripts.postActivation.text = ''
          if [ "$(cat /etc/ntp.conf 2>/dev/null)" != ${lib.escapeShellArg (lib.removeSuffix "\n" ntpConf)} ]; then
            printf '%s' ${lib.escapeShellArg ntpConf} > /etc/ntp.conf
            /bin/launchctl kickstart -k system/com.apple.timed >/dev/null 2>&1 || true
          fi
        '';
      };
  };

  # The LAN and tailnet's NTP server (NixOS): chrony, syncing from
  # `local.ntp.upstreamServers` and serving `ntpClients` on the interfaces in
  # `local.ntp.server.interfaces`.
  den.aspects.ntp.server = {
    nixos =
      { config, lib, ... }:
      {
        options.local.ntp.server.interfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          example = [
            "enp0s31f6"
            "tailscale0"
          ];
          description = "Network interfaces on which UDP port 123 is opened to NTP clients.";
        };

        config = {
          # chrony replaces timesyncd (its module turns timesyncd off). Its servers
          # are set here rather than taken from networking.timeServers, which the
          # client puts this host at the top of.
          services.chrony = {
            enable = true;
            servers = config.local.ntp.upstreamServers;
            extraConfig = lib.concatMapStrings (net: "allow ${net}\n") ntpClients;
          };

          networking.firewall.interfaces = lib.genAttrs config.local.ntp.server.interfaces (_: {
            allowedUDPPorts = [ port ];
          });
        };
      };
  };
}
