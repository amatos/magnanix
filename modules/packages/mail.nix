# Mail with Postfix on both platforms. `den.aspects.mail` (every host, through
# `base`) sends through the local network's SMTP smart relay;
# `den.aspects.mail.relay` (muninn) is that relay, and passes mail on to Fastmail.
#
# Every host:
# - Every message goes to `local.mail.relayHost` on port 25, without
#   authentication, using STARTTLS when the relay offers it. The relay is
#   `smtp.home.matos.cc` by default; the `tailscale` aspect switches it to
#   `smtp.ts.matos.cc`. Both names are CNAMEs for muninn, managed outside this flake.
# - Every sender address (envelope and From header) is rewritten to `address`.
# - Local mail for root (and postmaster, which goes to root) is forwarded to
#   `address` instead of a local mailbox nobody reads.
#
# NixOS runs its own Postfix (services.postfix). macOS keeps Apple's Postfix:
# activation sets the keys below in /etc/postfix/main.cf with `postconf -e`,
# leaving the rest of Apple's file alone. A macOS update can reset main.cf; the
# next switch puts the keys back.
let
  address = "alberth@matos.cc";
  relayPort = 25;

  # The relay's names, which clients use and its certificates are issued for.
  relayNames = [
    "smtp.home.matos.cc"
    "smtp.ts.matos.cc"
  ];

  # Fastmail's submission server, with implicit TLS, and the account the relay
  # logs in as. Its app password is `fastmail_smtp_password` in the relay host's
  # secrets file (secrets/hosts/<host>.yaml).
  fastmail = "[smtp.fastmail.com]:465";
  fastmailUser = "alberth@matos.cc";

  # Clients the relay accepts mail from: itself, the LAN, and the tailnet.
  relayClients = [
    "127.0.0.0/8"
    "[::1]/128"
    "10.0.4.0/22"
    "100.64.0.0/10" # Tailscale IPv4
    "[fd7a:115c:a1e0::]/48" # Tailscale IPv6
  ];

  # Shared by both platforms. The brackets stop Postfix looking up MX records
  # for the relay's name.
  relayhostFor = host: "[${host}]:${toString relayPort}";
  senderCanonical = "static:${address}";
in
{
  den.aspects.mail = {
    os =
      { lib, ... }:
      {
        options.local.mail.relayHost = lib.mkOption {
          type = lib.types.str;
          default = "smtp.home.matos.cc";
          description = "SMTP smart relay that all outgoing mail is sent to (port 25, no authentication).";
        };
      };

    nixos =
      { config, lib, ... }:
      {
        services.postfix = {
          enable = true;
          rootAlias = address;
          # Defaults, so `mail.relay` can override them on the relay host.
          # Send-only: no smtpd on port 25. Local mail is submitted with sendmail.
          enableSmtp = lib.mkDefault false;
          settings.main = {
            relayhost = lib.mkDefault [ (relayhostFor config.local.mail.relayHost) ];
            sender_canonical_maps = [ senderCanonical ];
            # The module's default, stated because the relay doesn't require TLS.
            smtp_tls_security_level = lib.mkDefault "may";
          };
        };
      };

    darwin =
      { config, lib, ... }:
      let
        # `inline:` needs no aliases file or `newaliases`. It comes before Apple's
        # /etc/aliases, so its root entry wins.
        settings = {
          relayhost = relayhostFor config.local.mail.relayHost;
          sender_canonical_maps = senderCanonical;
          smtp_tls_security_level = "may";
          alias_maps = "inline:{ root=${address} }, hash:/etc/aliases";
        };
      in
      {
        # Apple's master runs on demand (launchd starts it when mail is queued) and
        # exits when idle, so a reload is only needed if it happens to be running.
        system.activationScripts.postActivation.text = ''
          /usr/sbin/postconf -e ${
            lib.escapeShellArgs (lib.mapAttrsToList (name: value: "${name}=${value}") settings)
          }
          if /usr/sbin/postfix status >/dev/null 2>&1; then
            /usr/sbin/postfix reload >/dev/null 2>&1 || true
          fi
        '';
      };

    # The smart relay (NixOS). The host's own Postfix accepts mail on port 25 from
    # `relayClients` and sends it, and its own mail, to Fastmail. The host must also
    # include `certbot` and set `local.mail.relay.interfaces`.
    relay.nixos =
      { config, lib, ... }:
      let
        cfg = config.local.mail.relay;
        # One certificate is served for both names. Clients don't verify it
        # (smtp_tls_security_level = may), so either name's certificate will do.
        certDir = "/etc/letsencrypt-certs/${builtins.head relayNames}";
        saslPasswords = config.sops.templates.postfix-sasl-passwords.path;
      in
      {
        options.local.mail.relay.interfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          example = [
            "enp0s31f6"
            "tailscale0"
          ];
          description = "Network interfaces on which ports 25 and 465 are opened to relay clients.";
        };

        config = {
          local.certbot.fqdns = relayNames;

          sops.secrets.fastmail_smtp_password = { };
          # Postfix's SASL password table. Only root can read it; the smtp client
          # opens it before dropping privileges. `texthash` reads the file as is,
          # so it needs no `postmap`.
          sops.templates.postfix-sasl-passwords = {
            content = "${fastmail} ${fastmailUser}:${config.sops.placeholder.fastmail_smtp_password}\n";
            restartUnits = [ "postfix.service" ];
          };

          services.postfix = {
            enableSmtp = true;

            # Port 465 with implicit TLS, for clients that want it. The module adds
            # smtpd_tls_wrappermode = yes and smtpd_tls_security_level = encrypt.
            # Its default options require a SASL login, which this relay has no
            # server for, so these replace them: the same clients as port 25, and
            # no one else.
            enableSubmissions = true;
            submissionsOptions.smtpd_client_restrictions = "permit_mynetworks,reject";

            settings.main = {
              mynetworks = relayClients;
              # Rewrite the From header of relayed mail too (by default Postfix only
              # rewrites headers of mail submitted on this host), so Fastmail
              # accepts mail from the printer, router and NAS.
              local_header_rewrite_clients = [
                "permit_inet_interfaces"
                "permit_mynetworks"
              ];

              relayhost = [ fastmail ];
              smtp_tls_wrappermode = true;
              # Encrypt, and check the certificate is valid for smtp.fastmail.com.
              smtp_tls_security_level = "secure";
              smtp_sasl_auth_enable = true;
              smtp_sasl_password_maps = [ "texthash:${saslPasswords}" ];
              smtp_sasl_security_options = [ "noanonymous" ];

              # TLS for clients, once certbot has issued the certificate. Until then,
              # port 25 logs a warning and accepts mail without TLS, and port 465
              # can't complete a TLS handshake.
              smtpd_tls_chain_files = [
                "${certDir}/privkey.pem"
                "${certDir}/fullchain.pem"
              ];
            };
          };

          networking.firewall.interfaces = lib.genAttrs cfg.interfaces (_: {
            allowedTCPPorts = [
              relayPort
              465
            ];
          });
        };
      };
  };
}
