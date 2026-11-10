# Mail

Every host sends mail (cron output, `sendmail`, `mail`) through the network's SMTP smart relay, using
`den.aspects.mail` (`modules/packages/mail.nix`), which `base` includes. The relay is muninn, which passes the
mail on to Fastmail (see [The relay](#the-relay)). Other hosts only send; nothing on them listens for mail from the
network.

- **Relay:** `smtp.home.matos.cc`, or `smtp.ts.matos.cc` on hosts that include `den.aspects.tailscale`. The `tailscale` aspect makes the switch by setting `local.mail.relayHost`. Mail goes to port 25
  without authentication, using STARTTLS when the relay offers it. Both names are CNAMEs for muninn, managed
  outside this flake.
- **Addresses:** every sender address is rewritten to `alberth@matos.cc`, and local mail for `root` (and
  `postmaster`) is forwarded there.
- **NixOS** runs Postfix from `services.postfix`, with no `smtpd` on port 25 (except on the relay).
- **macOS** keeps Apple's Postfix. Each switch sets `relayhost`, `sender_canonical_maps`, `smtp_tls_security_level`
  and `alias_maps` in `/etc/postfix/main.cf` with `postconf -e` and leaves the rest of the file alone. A macOS update
  can reset `main.cf`; the next switch puts the keys back.

To test it, run `printf 'Subject: test\n\ntest\n' | sendmail root` and check that the queue is empty with `mailq`.
On NixOS, `journalctl -u postfix` shows why a message is stuck.

**Tailscale:** on macOS, the `tailscale` aspect installs the App Store app through `homebrew.masApps`, so you have to be signed in
to the App Store. On NixOS, log in to the tailnet once with `sudo tailscale up`.

## The relay

`den.aspects.mail.relay` (in `mail.nix`) turns the host's own Postfix into the relay:

- **Accepts** mail without authentication from the LAN (`10.0.4.0/22`), the tailnet (`100.64.0.0/10`,
  `fd7a:115c:a1e0::/48`) and the host itself, and relays it for no one else. It listens on port 25 (STARTTLS
  optional) and on port 465 (implicit TLS required). Both ports are open only on the interfaces in
  `local.mail.relay.interfaces`, set in the relay host's file.
- **Rewrites** the envelope sender and `From:` header of everything it relays to `alberth@matos.cc`, including mail
  from devices like the printer, router and NAS, because Fastmail only accepts senders that are the account's
  identities.
- **Sends** everything, its own mail included, to `smtp.fastmail.com:465` with implicit TLS, checking Fastmail's
  certificate, and logs in as `alberth@matos.cc` with an app password.
- **Uses the `smtp.home.matos.cc` certificate for TLS** on both ports. It requests that certificate through
  `local.certbot.fqdns`, along with `smtp.ts.matos.cc`, so the host must include `certbot`. Clients connecting by
  either name get the `smtp.home.matos.cc` certificate. The Nix hosts don't check it, but a device on port 465 that
  verifies the name has to use `smtp.home.matos.cc`. Until certbot has issued the certificate, port 25 accepts
  mail without TLS (and logs a warning), and port 465 fails.

The app password is `fastmail_smtp_password` in `secrets/hosts/muninn.yaml`, which only muninn and the YubiKeys can
decrypt. sops-nix writes it into Postfix's SASL password table at `/run/secrets/rendered/postfix-sasl-passwords`
(root only) and restarts Postfix when it changes. To replace it, create a new app password in Fastmail's settings
(Privacy & Security), paste it in with `sops secrets/hosts/muninn.yaml`, and switch muninn.
