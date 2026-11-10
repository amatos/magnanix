# Aspect:    den.aspects.certbot
# Platforms: nixos, darwin
# Purpose:   Let's Encrypt certificates through certbot and the LuaDNS DNS
#            plugin (pkgs/python/certbot-dns-luadns.nix), so a host needs no open
#            ports to prove it owns a name.
#
# Usage (in the host's darwin or nixos block):
#   local.certbot = { email = "..."; fqdns = [ "host.example.com" ]; };
#
# Notes:
# - Issuing: a boot-time service (launchd / systemd) requests every listed FQDN
#   that has no certificate yet, retrying every 15 minutes (slow enough to stay
#   under Let's Encrypt's 5 failed validations per hour) until all succeed.
#   A wildcard is named after its base domain, so `example.com` and
#   `*.example.com` can't both be listed.
# - Renewing: `certbot renew` runs daily (03:00 on macOS) and only touches
#   certificates that are due. nix-darwin has no services.certbot, so both
#   platforms use a plain timer rather than NixOS's declarative module.
# - Reading: /etc/letsencrypt is root-only (0700), and certbot may reset its
#   permissions, so a deploy hook copies each certificate and key to
#   /etc/letsencrypt-certs/<name>/: owned by the primary user (0400) on macOS,
#   readable by the `cert-readers` group (every normal user, 0440) on NixOS.
#   Point services at those copies.
# - Credentials: `certbot_luadns` in secrets/common.yaml (an INI file with
#   dns_luadns_email and dns_luadns_token), so the host must be a recipient
#   of common.yaml.
# - Manual issuance (`certbot certonly --dns-luadns --dns-luadns-credentials
#   /run/secrets/certbot_luadns -d example.com`) skips the deploy hook, so the
#   copy only appears after its first renewal.
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
