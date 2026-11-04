# The Attic binary cache on muninn: the server, and the client side every host uses
# to pull from it. See "Binary cache" in the README for creating the cache and its
# tokens.
let
  # The names clients reach the server by: LAN DNS and Tailscale.
  lanHost = "muninn.home.matos.cc";
  tailscaleHost = "muninn.ts.matos.cc";
  port = 8080;

  # The cache (`attic cache create magnanix`) and the key it signs paths with, as
  # printed by `attic cache info magnanix`. Recreating the cache changes the key.
  cacheName = "magnanix";
  publicKey = "magnanix:CqwRoN5bzF5FNtDByVxLzNm/O8lpZ+++pVopZr80TLY=";

  # Nix settings for a host that reaches the server as `host`. Nix trusts
  # substituters from the system config, so no `trusted-substituters` is needed.
  substituterSettings = host: {
    extra-substituters = [ "http://${host}:${toString port}/${cacheName}" ];
    extra-trusted-public-keys = [ publicKey ];
    # Nix's default (0) leaves curl's 300 s, so a host away from the cache would
    # stall on every substitution. Applies to every substituter, not just Attic.
    connect-timeout = 5;
  };
in
{
  # Client side, on every host (through `base`): substitute from the cache. It
  # advertises priority 41, after cache.nixos.org's 40, so it supplies what
  # cache.nixos.org lacks (unfree packages, this flake's own builds).
  # The server is `muninn.home.matos.cc` by default; the `tailscale` aspect
  # switches it to `muninn.ts.matos.cc`, the same way it switches the mail relay.
  den.aspects.attic.client = {
    homeManager = { pkgs, ... }: {
      # `attic` CLI for pushing to the cache. Available to every user via `base`
      # (included in all hosts). Login state (`~/.config/attic/config.toml`) lives
      # in the user's home, not system-wide.
      home.packages = [ pkgs.attic-client ];
    };

    os =
      { lib, ... }:
      {
        options.local.attic.serverHost = lib.mkOption {
          type = lib.types.str;
          default = lanHost;
          description = "Name this host reaches the Attic server by; it must be one of the server's allowed hosts.";
        };
      };

    darwin =
      { config, ... }:
      {
        determinateNix.customSettings = substituterSettings config.local.attic.serverHost;
      };

    nixos =
      { config, ... }:
      {
        nix.settings = substituterSettings config.local.attic.serverHost;
      };
  };

  # Attic binary cache server (NixOS). Serves the flake's build outputs, unfree
  # ones included, to the machines on the LAN and the tailnet.
  den.aspects.attic.server = {
    nixos =
      { config, pkgs, ... }:
      {
        services.atticd = {
          enable = true;

          # ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64, the key atticd signs its access
          # tokens with. Replacing it invalidates every token issued so far.
          environmentFile = config.sops.secrets.atticd_env.path;

          settings = {
            listen = "[::]:${toString port}";

            # atticd rejects any request whose Host header isn't one of these, before
            # doing anything else. With no fixed `api-endpoint`, it then builds the
            # URLs it returns from that Host header, so each client is answered under
            # the name it used. A fixed endpoint would send `attic push` from a
            # Tailscale client to the LAN name.
            allowed-hosts = map (host: "${host}:${toString port}") [
              lanHost
              tailscaleHost
            ];

            # Delete objects that were neither pushed nor downloaded in this long.
            # A cache can override it with `attic cache configure --retention-period`.
            garbage-collection.default-retention-period = "3 months";
          };
        };

        # From secrets/hosts/<host>.yaml. systemd reads the environment file as root
        # before starting atticd's dynamic user, so the default root-only mode works.
        sops.secrets.atticd_env = {
          restartUnits = [ "atticd.service" ];
          mode = "0400";
          owner = "atticd";
          group = "atticd";
        };

        networking.firewall.allowedTCPPorts = [ port ];
      };
  };
}
