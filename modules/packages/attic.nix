# The Attic binary cache on muninn: the server, the client side every host uses
# to pull from it, and the watcher that pushes a host's new store paths to it.
# See "Binary cache" in the README for creating the cache and its tokens.
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

  # The push watcher's name for the server in its client config, and the secret
  # (in secrets/hosts/<host>.yaml) holding the host's push token.
  serverName = "muninn";
  tokenSecret = "attic_push_token";

  # What the push watcher on a host needs, for both its systemd and launchd forms.
  pushWatcher =
    {
      config,
      lib,
      pkgs,
    }:
    rec {
      # sops-nix fails the build when a declared secret is missing from its file,
      # so the watcher only exists once the token is there. Until then every build
      # warns instead, and the rest of the host still builds and switches. sops
      # leaves the key names in plain text, so a top-level key starts a line.
      sopsFile = config.sops.defaultSopsFile;
      hasToken = lib.hasInfix "\n${tokenSecret}:" ("\n" + builtins.readFile sopsFile);
      warning = "attic.push: no `${tokenSecret}` in secrets/hosts/${baseNameOf sopsFile}, so this host doesn't push to the Attic cache. See \"Pushing to the cache\" in the README.";

      # The client config, used as the watcher's XDG_CONFIG_HOME. It reads the
      # token from the secret's file, so nothing has to run `attic login` or put
      # the token on a command line. watch-store never writes the config back,
      # so a read-only store path works.
      configHome = pkgs.writeTextFile {
        name = "attic-watch-store-config";
        destination = "/attic/config.toml";
        text = ''
          default-server = "${serverName}"

          [servers.${serverName}]
          endpoint = "http://${config.local.attic.serverHost}:${toString port}/"
          token-file = "${config.sops.secrets.${tokenSecret}.path}"
        '';
      };

      command = "${lib.getExe' pkgs.attic-client "attic"} watch-store ${serverName}:${cacheName}";
    };
in
{
  # Client side, on every host (through `base`): substitute from the cache. It
  # advertises priority 41, after cache.nixos.org's 40, so it supplies what
  # cache.nixos.org lacks (unfree packages, this flake's own builds).
  # The server is `muninn.home.matos.cc` by default; the `tailscale` aspect
  # switches it to `muninn.ts.matos.cc`, the same way it switches the mail relay.
  den.aspects.attic.client = {
    homeManager =
      { pkgs, ... }:
      {
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
        # Don't set owner/group: atticd uses DynamicUser, so there's no `atticd`
        # user for sops-install-secrets to look up and activation fails.
        sops.secrets.atticd_env.restartUnits = [ "atticd.service" ];

        networking.firewall.allowedTCPPorts = [ port ];
      };
  };

  # Push every new store path this host builds to the cache, with
  # `attic watch-store`. Paths cache.nixos.org already signs are skipped (the
  # cache's upstream filter). It runs as root, which can read the root-only token
  # secret, and reaches the server by `local.attic.serverHost` like the client.
  # If the server is unreachable (muninn down, the host away without Tailscale),
  # the watcher exits and is restarted until it gets through.
  den.aspects.attic.push = {
    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        watcher = pushWatcher { inherit config lib pkgs; };
      in
      {
        config = lib.mkMerge [
          { warnings = lib.optional (!watcher.hasToken) watcher.warning; }

          (lib.mkIf watcher.hasToken {
            sops.secrets.${tokenSecret}.restartUnits = [ "attic-watch-store.service" ];

            systemd.services.attic-watch-store = {
              description = "Push new Nix store paths to the Attic cache";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              # On the server itself, wait for atticd too.
              after = [ "network-online.target" ] ++ lib.optional config.services.atticd.enable "atticd.service";
              environment.XDG_CONFIG_HOME = "${watcher.configHome}";
              # Keep retrying however long the server is away.
              startLimitIntervalSec = 0;
              serviceConfig = {
                ExecStart = watcher.command;
                Restart = "always";
                # Back off from 10 s to 10 min over successive failures.
                RestartSec = "10s";
                RestartSteps = 10;
                RestartMaxDelaySec = "10min";
              };
            };
          })
        ];
      };

    darwin =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        watcher = pushWatcher { inherit config lib pkgs; };
      in
      {
        config = lib.mkMerge [
          { warnings = lib.optional (!watcher.hasToken) watcher.warning; }

          (lib.mkIf watcher.hasToken {
            sops.secrets.${tokenSecret} = { };

            # A daemon rather than a user agent: it runs without anyone logged in,
            # and as root it can read the secret.
            launchd.daemons.attic-watch-store = {
              # `command` waits for /nix/store to mount, which ProgramArguments wouldn't.
              command = watcher.command;
              serviceConfig = {
                EnvironmentVariables.XDG_CONFIG_HOME = "${watcher.configHome}";
                RunAtLoad = true;
                KeepAlive = true;
                # launchd has no backoff; wait a minute between restarts.
                ThrottleInterval = 60;
                StandardOutPath = "/var/log/attic-watch-store.log";
                StandardErrorPath = "/var/log/attic-watch-store.log";
              };
            };

            # The log gets a line per pushed path; keep five 1 MB files, compressed.
            environment.etc."newsyslog.d/attic-watch-store.conf".text = ''
              # logfilename                    mode count size(KB) when flags
              /var/log/attic-watch-store.log   644  5     1024     *    J
            '';
          })
        ];
      };
  };
}
