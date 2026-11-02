{
  # Attic binary cache server (NixOS). Serves the flake's build outputs, unfree
  # ones included, to the machines on the LAN; see "Binary cache" in the README for
  # creating the cache and its tokens.
  den.aspects.attic.server = {
    nixos =
      { config, pkgs, ... }:
      let
        # The names clients reach the server by: LAN DNS and Tailscale.
        hosts = [
          "muninn.home.matos.cc"
          "muninn.ts.matos.cc"
        ];
        port = 8080;
      in
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
            allowed-hosts = map (host: "${host}:${toString port}") hosts;

            # Delete objects that were neither pushed nor downloaded in this long.
            # A cache can override it with `attic cache configure --retention-period`.
            garbage-collection.default-retention-period = "3 months";
          };
        };

        # From secrets/hosts/<host>.yaml. systemd reads the environment file as root
        # before starting atticd's dynamic user, so the default root-only mode works.
        sops.secrets.atticd_env.restartUnits = [ "atticd.service" ];

        networking.firewall.allowedTCPPorts = [ port ];

        # The `attic` client, for creating the cache on the server itself.
        # `atticd-atticadm` (issuing tokens) comes with services.atticd.
        environment.systemPackages = [ pkgs.attic-client ];
      };
  };
}
