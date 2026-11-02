# Wires certbot + the certbot-dns-luadns plugin (pkgs/python/certbot-dns-luadns.nix)
# into a renewal timer that keeps existing certs renewed — launchd on darwin,
# systemd on nixos.
#
# nix-darwin has no `services.certbot` (that's NixOS-only), so renewal is a
# plain `certbot renew` on a timer instead of a fully declarative cert block.
# `renew` is idempotent and needs no domain argument — it just re-processes
# whatever's already under /etc/letsencrypt/renewal, so the schedule below
# works unconditionally, before any cert has ever been issued.
#
# Declarative issuance: set `local.certbot.fqdns` and `local.certbot.email`
# on the host. A service started at boot issues any listed FQDN not yet present
# under /etc/letsencrypt/renewal, retrying every 15 minutes until all succeed
# (slow enough to stay under Let's Encrypt's limit of 5 failed validations per
# hour), then the renewal timer takes over. Issuance is idempotent:
# already-present lineages are skipped. A wildcard's lineage is named after its
# base domain, so `example.com` and `*.example.com` can't both be listed.
#
# Manual issuance still works if preferred:
#   certbot certonly --dns-luadns \
#     --dns-luadns-credentials /run/secrets/certbot_luadns \
#     -d example.com
#
# The credentials are `certbot_luadns` in secrets/common.yaml, an INI file with
# `dns_luadns_email` and `dns_luadns_token`.
#
# /etc/letsencrypt/archive/<lineage> is 0700 root:root (0700 root:wheel on
# darwin), so no non-root service can read the key material there even from a
# chown'd copy of just the files -- the directory itself blocks traversal.
# Rather than loosen certbot's own directory perms (which it may reset on a
# future renewal), each platform's deploy-hook below copies each issued or
# renewed lineage out to /etc/letsencrypt-certs/<lineage> instead: 0400 owned by
# the host's primary user on darwin, 0440 owned by a dedicated group on nixos
# (no single "primary user" concept there). Consumers should read certs from
# there, not from /etc/letsencrypt directly. Manual issuance doesn't run the
# hook unless given `--deploy-hook`, so nothing is copied until the first renewal.
{
  den.aspects.certbot = {
    darwin =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.local.certbot;

        certbotWithPlugins = pkgs.certbot.withPlugins (cp: [
          (cp.callPackage ../../pkgs/python/certbot-dns-luadns.nix { })
        ]);

        deployHook = pkgs.writeShellApplication {
          name = "certbot-deploy-copy-for-user";
          runtimeInputs = [ pkgs.coreutils ];
          text = ''
            target_user=${lib.escapeShellArg config.system.primaryUser}
            lineage="$(basename "$RENEWED_LINEAGE")"
            dest="/etc/letsencrypt-certs/$lineage"
            install -d -m 0755 /etc/letsencrypt-certs
            install -d -o "$target_user" -m 0700 "$dest"
            install -o "$target_user" -m 0400 "$RENEWED_LINEAGE/fullchain.pem" "$dest/fullchain.pem"
            install -o "$target_user" -m 0400 "$RENEWED_LINEAGE/privkey.pem" "$dest/privkey.pem"
          '';
        };

        # FQDNs are passed as "$@" so the script is valid even when the list
        # is empty (it's only instantiated as a daemon when fqdns != []).
        issueScript = pkgs.writeShellApplication {
          name = "certbot-issue-certs";
          runtimeInputs = [
            certbotWithPlugins
            pkgs.coreutils
          ];
          text = ''
            credentials=${lib.escapeShellArg config.sops.secrets.certbot_luadns.path}
            failed=0
            for fqdn in "$@"; do
              cert_name="''${fqdn#\*.}"
              if [[ ! -f "/etc/letsencrypt/renewal/$cert_name.conf" ]]; then
                if ! certbot certonly \
                  --dns-luadns \
                  --dns-luadns-credentials "$credentials" \
                  --non-interactive \
                  --agree-tos \
                  --email ${lib.escapeShellArg cfg.email} \
                  --deploy-hook ${lib.getExe deployHook} \
                  --cert-name "$cert_name" \
                  -d "$fqdn"; then
                  echo "certbot: failed to issue $fqdn" >&2
                  failed=1
                fi
              fi
            done
            exit "$failed"
          '';
        };
      in
      {
        options.local.certbot = {
          email = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "ACME registration email. Required when fqdns is non-empty.";
          };
          fqdns = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "FQDNs to issue certificates for at boot if not already issued. Ongoing renewals are automatic.";
          };
        };

        config = {
          assertions = [
            {
              assertion = cfg.fqdns == [ ] || cfg.email != "";
              message = "local.certbot.email must be set when local.certbot.fqdns is non-empty.";
            }
          ];

          sops.secrets.certbot_luadns.sopsFile = ../../secrets/common.yaml;

          environment.systemPackages = [ certbotWithPlugins ];

          launchd.daemons.certbot-renew = {
            command = "${certbotWithPlugins}/bin/certbot renew --non-interactive --deploy-hook ${lib.getExe deployHook}";
            serviceConfig = {
              # Daily; `renew` is a no-op unless a cert is due.
              StartCalendarInterval = [
                {
                  Hour = 3;
                  Minute = 0;
                }
              ];
              StandardOutPath = "/var/log/certbot-renew.log";
              StandardErrorPath = "/var/log/certbot-renew.log";
            };
          };

          launchd.daemons.certbot-issue = lib.mkIf (cfg.fqdns != [ ]) {
            # `command` waits for /nix/store to mount, which ProgramArguments wouldn't.
            command = "${lib.getExe issueScript} ${lib.escapeShellArgs cfg.fqdns}";
            serviceConfig = {
              RunAtLoad = true;
              # launchd can't wait for the network, so retry until issuance succeeds.
              KeepAlive.SuccessfulExit = false;
              ThrottleInterval = 900;
              StandardOutPath = "/var/log/certbot-issue.log";
              StandardErrorPath = "/var/log/certbot-issue.log";
            };
          };
        };
      };

    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.local.certbot;

        certbotWithPlugins = pkgs.certbot.withPlugins (cp: [
          (cp.callPackage ../../pkgs/python/certbot-dns-luadns.nix { })
        ]);

        # NixOS has no nix-darwin-style single "primary user", so grant read
        # access via a dedicated group instead of chowning to one account.
        certReaders = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser or false) config.users.users);

        deployHook = pkgs.writeShellApplication {
          name = "certbot-deploy-copy-for-user";
          runtimeInputs = [ pkgs.coreutils ];
          text = ''
            lineage="$(basename "$RENEWED_LINEAGE")"
            dest="/etc/letsencrypt-certs/$lineage"
            install -d -m 0755 /etc/letsencrypt-certs
            install -d -g cert-readers -m 0750 "$dest"
            install -g cert-readers -m 0440 "$RENEWED_LINEAGE/fullchain.pem" "$dest/fullchain.pem"
            install -g cert-readers -m 0440 "$RENEWED_LINEAGE/privkey.pem" "$dest/privkey.pem"
          '';
        };

        issueScript = pkgs.writeShellApplication {
          name = "certbot-issue-certs";
          runtimeInputs = [
            certbotWithPlugins
            pkgs.coreutils
          ];
          text = ''
            credentials=${lib.escapeShellArg config.sops.secrets.certbot_luadns.path}
            failed=0
            for fqdn in "$@"; do
              cert_name="''${fqdn#\*.}"
              if [[ ! -f "/etc/letsencrypt/renewal/$cert_name.conf" ]]; then
                if ! certbot certonly \
                  --dns-luadns \
                  --dns-luadns-credentials "$credentials" \
                  --non-interactive \
                  --agree-tos \
                  --email ${lib.escapeShellArg cfg.email} \
                  --deploy-hook ${lib.getExe deployHook} \
                  --cert-name "$cert_name" \
                  -d "$fqdn"; then
                  echo "certbot: failed to issue $fqdn" >&2
                  failed=1
                fi
              fi
            done
            exit "$failed"
          '';
        };
      in
      {
        options.local.certbot = {
          email = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "ACME registration email. Required when fqdns is non-empty.";
          };
          fqdns = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "FQDNs to issue certificates for at boot if not already issued. Ongoing renewals are automatic.";
          };
        };

        config = {
          assertions = [
            {
              assertion = cfg.fqdns == [ ] || cfg.email != "";
              message = "local.certbot.email must be set when local.certbot.fqdns is non-empty.";
            }
          ];

          sops.secrets.certbot_luadns.sopsFile = ../../secrets/common.yaml;

          environment.systemPackages = [ certbotWithPlugins ];

          users.groups.cert-readers.members = certReaders;

          systemd.services.certbot-renew = {
            description = "Renew certbot certificates";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${certbotWithPlugins}/bin/certbot renew --non-interactive --deploy-hook ${lib.getExe deployHook}";
            };
          };

          systemd.timers.certbot-renew = {
            description = "Renew certbot certificates daily";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "daily";
              Persistent = true;
            };
          };

          systemd.services.certbot-issue = lib.mkIf (cfg.fqdns != [ ]) {
            description = "Issue certbot certificates for declared FQDNs";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              # network-online.target doesn't guarantee DNS is working.
              Restart = "on-failure";
              RestartSec = "15min";
              ExecStart = "${lib.getExe issueScript} ${lib.escapeShellArgs cfg.fqdns}";
            };
          };
        };
      };
  };
}
