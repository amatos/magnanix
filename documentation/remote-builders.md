# Remote builders

magnus (aarch64-darwin) builds Linux derivations in two ways:

- **aarch64-linux** builds on magnus itself, in Determinate's Native Linux Builder. Each build runs in a
  short-lived VM (macOS Virtualization framework) that exits when the build finishes, so nothing sits idle.
- **x86_64-linux** goes to fortuna, then muninn. If neither answers, it runs on magnus under Rosetta, in the
  same Native Linux Builder.

With this in place, `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` works on magnus for any
NixOS host, including `tenabrae`, which never builds anything itself.

The configuration is in `modules/packages/remote-build.nix`:

- **`den.aspects.remote-build.server`** (fortuna, muninn) sets up `nix.sshServe` with `ssh-ng`. That creates
  `nix-ssh`, a trusted Nix user whose only command is `nix-daemon --stdio`, and lets only magnus's builder key log
  in as it.
- **`den.aspects.remote-build.client`** (magnus):
  - enables the Native Linux Builder, at 4 GiB and 1 CPU per build VM;
  - sets `determinateNix.buildMachines` and `distributedBuilds`, which together write `/etc/nix/machines`;
  - sets `builders-use-substitutes`, so builders download dependencies from the caches themselves instead of
    through magnus.

| Builder                       | Systems                  | Order                           |
| ----------------------------- | ------------------------ | ------------------------------- |
| magnus (Native Linux Builder) | aarch64-linux            | always                          |
| `fortuna`                     | x86_64-linux             | first (speed 4, 8 jobs)         |
| `muninn`                      | x86_64-linux             | fallback (speed 1, 4 jobs)      |
| magnus (Rosetta)              | x86_64-linux             | when neither fortuna nor muninn |

When a reachable remote builder supports a derivation's system, Nix sends the build there rather than building
locally. That's why the remote builders list only `x86_64-linux`. If they also listed `aarch64-linux`, aarch64
builds would leave magnus and run under emulation.

## Native Linux Builder

- **Login:** it needs magnus logged in to FlakeHub (`sudo determinate-nixd login`). A free account is enough.
  Check with `determinate-nixd status`.
- **Registration:** it registers as an external builder; `nix config show external-builders` lists its systems.
- **Resources:** each build VM gets 1 CPU (Determinate advises against more) and `nativeBuilderMemory` (4 GiB).
  Several builds at once mean several VMs, so a large aarch64 build uses a noticeable share of magnus while it
  runs.

## Attic

Builds done on fortuna and muninn are pushed to Attic by their own `attic.push` watchers. Builds done on magnus,
including aarch64 builds in the Native Linux Builder, are pushed by magnus's watcher. fortuna's watcher only starts once `attic_push_token` is in `secrets/hosts/fortuna.yaml`. To set
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
nix build --rebuild nixpkgs#legacyPackages.aarch64-linux.hello -L    # builds locally, in the Native Linux Builder
```
