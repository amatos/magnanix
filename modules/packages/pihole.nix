# Aspect:    den.aspects.pihole
# Platforms: nixos
# Purpose:   Pi-hole: pihole-FTL answering DNS for the LAN and the tailnet with
#            ad and tracker blocking, its web dashboard, and Unbound forwarding
#            every query to Quad9 over DNS-over-TLS.
#
# Usage (in the host's nixos block):
#   local.pihole.interfaces = [ "wlan0" "tailscale0" ];
#
# Notes:
# - Query path: client -> pihole-FTL (port 53) -> Unbound (127.0.0.1:5335) ->
#   Quad9 (9.9.9.9 / 149.112.112.112, port 853, TLS, name dns.quad9.net). No
#   query leaves the host in plain text.
# - DNS (53) and the dashboard (80) are opened only on local.pihole.interfaces.
#   FTL listens on all interfaces (listeningMode ALL) because its default, LOCAL,
#   drops tailnet queries: tailscale0 has a /32, so no client is "local" to it.
# - No DHCP: the router keeps handing out addresses, with this host as its DNS.
# - Dashboard password: `pihole_env` in the host's secrets file, a line
#   `FTLCONF_webserver_api_password=...`. FTL reads FTLCONF_* variables over
#   pihole.toml and hashes the password itself, so the plain text never reaches
#   the Nix store. Without it the dashboard is open to anyone who can reach it.
# - Configuration is immutable (misc.readOnly): change it here, not in the
#   dashboard. Blocklists come from `services.pihole-ftl.lists` below.
# - DoT needs a sane clock to validate Quad9's certificate. A board without an
#   RTC boots in the past, so the host's NTP servers must not need this resolver
#   (see the IP-based time servers in tenabrae.nix).
{
  den.aspects.pihole = {
    nixos =
      { config, lib, ... }:
      let
        cfg = config.local.pihole;
        unboundPort = 5335;
        dashboardPort = 80;
      in
      {
        options.local.pihole.interfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          example = [
            "wlan0"
            "tailscale0"
          ];
          description = "Interfaces on which Pi-hole's DNS (53) and dashboard (80) ports are opened.";
        };

        config = {
          services.pihole-ftl = {
            enable = true;
            queryLogDeleter.enable = true;
            lists = [
              {
                url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
                description = "Steven Black's unified adlist";
              }
            ];
            settings = {
              dns = {
                upstreams = [ "127.0.0.1#${toString unboundPort}" ];
                listeningMode = "ALL";
                domainNeeded = true;
                bogusPriv = true;
              };
              dhcp.active = false;
            };
          };

          services.pihole-web = {
            enable = true;
            ports = [ (toString dashboardPort) ];
          };

          # The dashboard password, as an FTLCONF_ override (see the header).
          sops.secrets.pihole_env = { };
          systemd.services.pihole-ftl.serviceConfig.EnvironmentFile = config.sops.secrets.pihole_env.path;

          # Pi-hole's only upstream: Quad9 over DNS-over-TLS. Pi-hole caches, so
          # Unbound's own cache stays small to spare RAM.
          services.unbound = {
            enable = true;
            # The host's own lookups go through DHCP's DNS, not straight to Unbound
            resolveLocalQueries = false;
            settings = {
              server = {
                interface = [ "127.0.0.1" ];
                port = unboundPort;
                access-control = [ "127.0.0.0/8 allow" ];
                tls-cert-bundle = "/etc/ssl/certs/ca-certificates.crt";
                msg-cache-size = "4m";
                rrset-cache-size = "8m";
                num-threads = 1;
              };
              forward-zone = [
                {
                  name = ".";
                  forward-tls-upstream = true;
                  forward-addr = [
                    "9.9.9.9@853#dns.quad9.net"
                    "149.112.112.112@853#dns.quad9.net"
                    "2620:fe::fe@853#dns.quad9.net"
                    "2620:fe::9@853#dns.quad9.net"
                  ];
                }
              ];
            };
          };

          networking.firewall.interfaces = lib.genAttrs cfg.interfaces (_: {
            allowedTCPPorts = [
              53
              dashboardPort
            ];
            allowedUDPPorts = [ 53 ];
          });
        };
      };
  };
}
