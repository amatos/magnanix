# Binary cache

`muninn` runs an [Attic](https://github.com/zhaofengli/attic) binary cache server, from `den.aspects.attic.server`
(`modules/packages/attic.nix`). It serves port 8080 (open in `muninn`'s firewall) under two names:
`muninn.home.matos.cc` on the LAN and `muninn.ts.matos.cc` over Tailscale. It rejects requests addressed to any
other name, such as an IP address. The URLs it hands out (for `attic push`, for example) use whichever of the two
names the client used, so a client off the LAN can use the Tailscale name throughout. The data and its
SQLite database live in `/var/lib/atticd`. Objects that were neither pushed nor downloaded in the last 3 months
are garbage-collected.

The server signs its access tokens with `atticd_env` in `secrets/hosts/muninn.yaml`, an environment file that
sets `ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64`. Replacing it invalidates every token issued with it. To rotate it,
generate a key with `openssl genrsa -traditional 4096 | openssl base64 -A` and paste it in with
`sops secrets/hosts/muninn.yaml`.

Caches and tokens are created with commands, not from the flake. After the first switch on `muninn`, run this
there once:

```sh
# An admin token; keep it in 1Password
atticd-atticadm make-token --sub alberth --validity "1y" \
  --pull '*' --push '*' --delete '*' --create-cache '*' --configure-cache '*' \
  --configure-cache-retention '*' --destroy-cache '*'

attic login muninn http://muninn.home.matos.cc:8080/ <admin-token>
attic cache create magnanix --public   # anyone on the LAN can pull; pushing needs a token
attic cache info magnanix              # prints the public key that clients trust
```

A machine that only pushes gets a narrower token (see [Pushing to the cache](#pushing-to-the-cache)).

## Using the cache

Every host pulls from the cache through `den.aspects.attic.client` (in `attic.nix`), which `base` includes. It
adds the cache to `extra-substituters` and its public key to `extra-trusted-public-keys`. The cache advertises
priority 41 and cache.nixos.org 40 (lower wins), so Nix still takes what cache.nixos.org has from there, and gets
the rest (unfree packages, the flake's own builds) from muninn. On macOS these land in `determinateNix.customSettings`, on NixOS in `nix.settings`;
both end up in `/etc/nix/nix.custom.conf`.

- **Server name:** `muninn.home.matos.cc` by default; the `tailscale` aspect switches it to
  `muninn.ts.matos.cc` through `local.attic.serverHost`, the same way it switches the mail relay.
- **Unreachable cache:** the client also sets `connect-timeout = 5`, so a host that can't reach muninn (off the
  LAN, or with Tailscale down) loses a few seconds rather than curl's default 300 s before Nix skips the cache.
  The setting applies to every substituter.
- **Recreating the cache** changes its signing key. Update `publicKey` in `attic.nix` with the output of
  `attic cache info magnanix`, or substitution from it fails signature checks.

Pulling needs no token because the cache is public. Pushing by hand (`attic push magnanix <path>`) needs
`attic login` with a push token on that machine.

## Pushing to the cache

`den.aspects.attic.push` (in `attic.nix`) runs `attic watch-store` as root,
which pushes every store path that becomes valid on the host, with its closure, to `magnanix`. That covers both
builds and downloads, but paths signed by cache.nixos.org are skipped, so in practice it pushes the host's own
builds and the unfree packages. On NixOS it is the `attic-watch-store` systemd service; on macOS it is the
`org.nixos.attic-watch-store` launchd daemon, which logs to `/var/log/attic-watch-store.log` (rotated by
`newsyslog`).

- **Server name:** the same `local.attic.serverHost` the host pulls from (the Tailscale name on hosts with the
  `tailscale` aspect). On the server itself it reaches its own atticd through that name and starts after `atticd.service`.
- **Token:** `attic_push_token` in the host's `secrets/hosts/<host>.yaml`, decrypted to
  `/run/secrets/attic_push_token` (root only). The watcher's client config is generated in the Nix store and
  reads the token from that file, so nothing runs `attic login`, and the users' own `~/.config/attic` is
  untouched.
- **Server away:** if the server can't be reached when it starts, the watcher exits and is restarted: systemd
  backs off from 10 s to 10 min, launchd retries every minute. A rejected token doesn't stop it; each push
  fails with an error in the log (`journalctl -u attic-watch-store` on NixOS).
- **No token yet:** sops-nix fails the build when a declared secret is missing from its file, so the watcher and
  its secret only exist once the host's file has `attic_push_token`. Until then each build prints an
  `attic.push: no attic_push_token ...` warning, and the rest of the host builds and switches as usual.

To set it up for a host:

1. On muninn, mint a push token for the host:

   ```sh
   atticd-atticadm make-token --sub <host> --validity "1y" --pull magnanix --push magnanix
   ```

2. Add it to the host's secrets as `attic_push_token`, on its own line at the top level (just the token, no
   quotes or `Bearer`):

   ```sh
   sops secrets/hosts/<host>.yaml      # attic_push_token: <token>
   ```

3. Commit, and switch the host. The warning goes away and the watcher starts.

The token expires after a year. To replace it, mint a new one and repeat step 2. On NixOS the switch restarts
the watcher; on macOS restart it by hand with `sudo launchctl kickstart -k system/org.nixos.attic-watch-store`.
