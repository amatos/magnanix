# TLS certificates

`den.aspects.certbot` (`modules/packages/certbot.nix`) gets Let's Encrypt
certificates with certbot and the LuaDNS DNS plugin (`pkgs/python/certbot-dns-luadns.nix`), so a host needs no
open ports to prove it owns a name. A host lists its names in its `darwin` or `nixos` block:

```nix
local.certbot = {
  email = "alberth@matos.cc";   # required when fqdns isn't empty
  fqdns = [ "muninn.home.matos.cc" "muninn.ts.matos.cc" ];
};
```

magnus, muninn and fortuna use it, each requesting `<host>.home.matos.cc` and `<host>.ts.matos.cc`. The SMTP relay
host also gets `smtp.home.matos.cc` and `smtp.ts.matos.cc` (see [Mail](mail.md)). Fortuna's are for services added
later (Syncthing and the like); Sunshine keeps its own self-signed certificate, because Moonlight pins the certificate
it paired with and would need re-pairing after every renewal.

- **Issuing:** a service started at boot (launchd on macOS, systemd on NixOS) requests each listed name that has no
  certificate yet, and retries every 15 minutes until all succeed. Names that already have one are skipped.
  A wildcard's certificate is named after its base domain, so `example.com` and `*.example.com` can't both be listed.
- **Renewing:** `certbot renew` runs daily (03:00 on macOS) and only renews certificates that are due.
- **Reading them:** certbot keeps its files in `/etc/letsencrypt`, readable only by root. After each issue or
  renewal, a hook copies the certificate and key to `/etc/letsencrypt-certs/<name>/`, owned by the primary user on
  macOS and readable by the `cert-readers` group (every normal user) on NixOS. Point services at those copies.

The LuaDNS credentials are `certbot_luadns` in `secrets/common.yaml`: an INI file with `dns_luadns_email` and
`dns_luadns_token`. A host using certbot must be a recipient of `common.yaml`.

To request a certificate by hand instead (it is only copied to `/etc/letsencrypt-certs` from its first renewal):

```sh
sudo certbot certonly --dns-luadns --dns-luadns-credentials /run/secrets/certbot_luadns -d example.com
```
