# Remote builders

magnus (aarch64-darwin) can't build Linux derivations itself, so it sends them to fortuna, then muninn:

- **x86_64-linux** builds natively there.
- **aarch64-linux** builds under QEMU emulation on those x86_64 machines.

If neither builder answers, Determinate's Native Linux Builder on magnus is the last resort. It can't build
NixOS systems (see below).

With this in place, `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` works on magnus for any
NixOS host, including `tenabrae`, which never builds anything itself.

The configuration is in `modules/packages/remote-build.nix`:

- **`den.aspects.remote-build.server`** (fortuna, muninn) sets up `nix.sshServe` with `ssh-ng`. That creates
  `nix-ssh`, a trusted Nix user whose only command is `nix-daemon --stdio`, and lets only magnus's builder key log
  in as it. It also registers QEMU (`boot.binfmt.emulatedSystems`) on x86_64.
- **`den.aspects.remote-build.client`** (magnus):
  - sets `determinateNix.buildMachines` and `distributedBuilds`, which together write `/etc/nix/machines`;
  - sets `builders-use-substitutes`, so builders download dependencies from the caches themselves instead of
    through magnus;
  - keeps the Native Linux Builder enabled, at 4 GiB and 1 CPU per build VM.

| Builder                       | Systems                            | Order                      |
| ----------------------------- | ---------------------------------- | -------------------------- |
| `fortuna`                     | x86_64-linux, aarch64-linux (QEMU) | first (speed 4, 8 jobs)    |
| `muninn`                      | x86_64-linux, aarch64-linux (QEMU) | fallback (speed 1, 4 jobs) |
| magnus (Native Linux Builder) | aarch64-linux, x86_64-linux        | last resort                |

When a reachable remote builder supports a derivation's system, Nix sends the build there rather than building
locally. Builds only fall back to magnus when fortuna and muninn are both unreachable.

Emulated aarch64 is several times slower than native. That's fine when the heavy parts come from cache.nixos.org
or Attic, as with tenabrae. It's slow if something large misses the cache.

## Native Linux Builder

**It can't build NixOS systems.** Its VM reads magnus's `/nix/store`, which is case-insensitive APFS. Some Linux
store paths contain names that differ only by case, such as ncurses' `terminfo/L` and `terminfo/l`, or netfilter's
`xt_DSCP` and `xt_dscp`. To store both on magnus, Nix renames one of them (`l~nix~case~hack~1`), and the VM sees the
renamed copy. tenabrae's initrd failed this way, looking for `terminfo/l/linux`. Small derivations work.

- **Login:** it needs magnus logged in to FlakeHub (`sudo determinate-nixd login`). A free account is enough.
  Check with `determinate-nixd status`.
- **Registration:** it registers as an external builder; `nix config show external-builders` lists its systems.
- **Resources:** each build VM gets 1 CPU (Determinate advises against more) and `nativeBuilderMemory` (4 GiB).
  Several builds at once mean several VMs, so a large aarch64 build uses a noticeable share of magnus while it
  runs.

## Attic

Builds done on fortuna and muninn are pushed to Attic by their own `attic.push` watchers. fortuna's watcher only starts once `attic_push_token` is in `secrets/hosts/fortuna.yaml`. To set
it up, see "Pushing to the cache" in [Binary cache](binary-cache.md).

## Keys

- **Client key:** `/etc/nix/builder_ed25519` on magnus, owned by root with mode 600. Its public half is in
  `clientKeys` in `remote-build.nix`. The private half was generated off-host; keep a copy in 1Password. Install it
  with:

  ```sh
  sudo install -m 600 -o root -g wheel builder_ed25519 /etc/nix/builder_ed25519
  sudo install -m 644 -o root -g wheel builder_ed25519.pub /etc/nix/builder_ed25519.pub
  ```

- **Host keys:** each builder's `ssh_host_ed25519_key.pub` is pinned in `remote-build.nix`, base64-encoded as
  `publicHostKey`. Root on magnus doesn't need `known_hosts` entries for them. They are the same keys the hosts
  decrypt sops secrets with (`host_fortuna` and `host_muninn` in `.sops.yaml`).

## Checking it

```sh
# On magnus, after switching magnus, fortuna and muninn:
sudo ssh -i /etc/nix/builder_ed25519 nix-ssh@fortuna.home.matos.cc   # should hang waiting for the daemon protocol; Ctrl-C
nix store info --store ssh-ng://nix-ssh@fortuna.home.matos.cc        # as root, or via the daemon
nix build --rebuild nixpkgs#legacyPackages.x86_64-linux.hello -L     # should print "building ... on ssh-ng://nix-ssh@fortuna..."
nix build --rebuild nixpkgs#legacyPackages.aarch64-linux.hello -L    # also on fortuna, under QEMU
```
