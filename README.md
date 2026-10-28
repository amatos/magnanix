# magnanix

My nix flake, using the denful pattern for NixOS, nix-darwin, and home-manager, using Determinate Nix.

Configuration is organised with [Den](https://github.com/denful/den), an aspect-oriented Nix framework: a
feature (an *aspect*) is written once and can configure `nixos`, `darwin` and `homeManager` together. Hosts
and users simply pick the aspects they want.

## Hosts

| Host         | Platform         | Kind       |
| ------------ | ---------------- | ---------- |
| `magnus`     | `aarch64-darwin` | nix-darwin |
| `darwintron` | `aarch64-darwin` | nix-darwin |
| `nixostron`  | `x86_64-linux`   | NixOS      |

Each host has the user `alberth`. A host's name must match `scutil --get LocalHostName` (macOS) or
`hostname` (NixOS), so that `darwin-rebuild` / `nixos-rebuild` can find it.

## Layout

`flake.nix` loads every module under `modules/` with [import-tree](https://github.com/denful/import-tree) and
exposes the `darwinConfigurations` and `nixosConfigurations` that Den builds, plus the dev shell and formatter.
Any file or directory whose name starts with `_` is ignored by import-tree.

```
flake.nix                      inputs and outputs
flake.lock                     pinned inputs
.envrc                         direnv: `use flake` (loads the dev shell)
.sops.yaml                     sops recipients and creation rules
secrets/                       encrypted secrets (common, per host, per user)
modules/
├── den/                       the framework and features shared by all hosts
│   ├── den.nix                imports Den's flake module
│   ├── base.nix               baseline for every host (includes the hostname battery)
│   ├── determinate.nix        Determinate Nix modules and settings (macOS and NixOS)
│   ├── sops.nix               sops-nix (system and Home Manager) and secrets file wiring
│   ├── homebrew.nix           nix-homebrew (macOS only)
│   └── home-manager.nix       Home Manager integration for all users
├── host-features/             opt-in aspects that hosts include (none yet)
├── home-features/             opt-in aspects that users include
│   └── gpg.nix                GnuPG: Home Manager config, GPG Suite cask (macOS)
├── hosts/                     one file per host: den.hosts.* and den.aspects.<host>
│   ├── _darwin_template.nix   copy this to add a macOS host
│   └── _nix_template.nix      copy this to add a NixOS host
└── users/
    ├── _user_template/        copy this to add a user
    └── alberth/               den.aspects.alberth
        ├── alberth.nix        the user's aspect and metadata
        └── F41BDBF6171A3BB4.pub.asc   alberth's GPG public key
```

The `base`, `determinate`, `sops` and `homebrew` aspects are added to every host through `den.default.includes`.
Per-host settings go in `den.aspects.<host>`, and per-user settings in `den.aspects.<user>` (its `homeManager`
attribute is the user's Home Manager configuration).

### Features

The aspects in `modules/den/` apply to every host. Optional features live in their own directories and apply only
where something includes them:

- `modules/home-features/` holds features a user opts into, such as `gpg`. Include one from the user's aspect:

  ```nix
  den.aspects.alberth.includes = [ den.aspects.gpg ];
  ```

- `modules/host-features/` is for features a host opts into, included the same way from `den.aspects.<host>`.
  It is empty for now.

A feature can target several classes at once. `gpg`, for example, sets Home Manager options (`homeManager`) and
installs the GPG Suite cask (`darwin`). Its Home Manager part reads the user's metadata, so it adapts to each user.

### User metadata

A user's aspect carries a `meta` attribute set. It is defined in a `let` binding in the user's file and exposed with
`inherit meta;`, so it can be used inside the aspect itself and read by features through
`den.aspects.<user>.meta`. `alberth` uses:

| Attribute        | Purpose                                                              |
| ---------------- | -------------------------------------------------------------------- |
| `username`       | the account name                                                     |
| `fullName`       | display name for the OS account                                      |
| `email`          | primary email address                                                |
| `authorizedKeys` | SSH public keys allowed to log in (NixOS)                            |
| `gpgKey`         | long GPG key ID; sets `default-key` (optional)                       |
| `gpgFingerprint` | full 40-character fingerprint of the key                             |
| `gpgPublicKey`   | path to the exported public key (`.pub.asc`); imported with ultimate trust (optional) |

The `gpg` feature only sets `default-key` and imports a public key when `gpgKey` and `gpgPublicKey` exist, so users
without a GPG key still work. The `.pub.asc` file must be tracked by git for flakes to see it.
Export it with `gpg --export --armor <key-id> > modules/users/<user>/<key-id>.pub.asc`.

On macOS the `gpg` feature installs GPG Suite and keeps the Nix `gnupg` too. GPG Suite's installer puts its tools
on `PATH` through `/etc/paths.d/MacGPG2` and a `/usr/local/bin/gpg` symlink; the feature deletes both after every
activation (the symlink only if it points at GPG Suite) so the Nix `gpg` is not shadowed. The agent itself stays
GPG Suite's, and `gpg-agent.conf` and `dirmngr.conf` are left to GPG Suite; Home Manager only writes `gpg.conf`.

### Determinate Nix settings

`modules/den/determinate.nix` keeps the settings shared by every host (parallel evaluation and build-time flake
inputs) in one `sharedSettings` binding. nix-darwin takes them as `determinateNix.customSettings` and NixOS as
`nix.settings`; both end up in `/etc/nix/nix.custom.conf`. Put a setting in `sharedSettings` if it applies to all
hosts, or directly in the `darwin` / `nixos` block if it applies to one platform.

## Applying the configuration

Enter the dev shell and run the `apply-configuration` script. It picks the right command for the machine and
uses the machine's host name:

```sh
nix develop --command apply-configuration
```

- On macOS it runs `sudo darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"`.
- On NixOS it runs `sudo nixos-rebuild switch --flake ".#$(hostname)"`.

To build without activating:

```sh
darwin-rebuild build --flake .#magnus      # macOS
nixos-rebuild build --flake .#nixostron    # NixOS
```

## Adding a host

1. Copy `modules/hosts/_darwin_template.nix` or `_nix_template.nix` to `modules/hosts/<hostname>.nix`.
2. Replace `CHANGE_HOSTNAME` and `CHANGE_USERNAME`, and set the platform and `system.stateVersion`.
3. For secrets, add the host's age key (and the user's per-machine key) and a creation rule to `.sops.yaml`, then
   create `secrets/hosts/<hostname>.yaml`. No Nix change is needed: the `sops` aspect points each host at
   `secrets/hosts/<hostname>.yaml` by name.
4. New files must be tracked by git for flakes to see them (`git add` them).

## Adding a user

1. Copy `modules/users/_user_template/` to `modules/users/<username>/`.
2. Replace `CHANGE_USERNAME` and set `home.stateVersion`.
3. Add the user to a host with `den.hosts.<system>.<host>.users.<username> = { };`.
4. Optionally add a `meta` set (see [User metadata](#user-metadata)) and include features from `home-features/`.

## Secrets

Secrets are encrypted with [sops](https://github.com/getsops/sops) using age. `.sops.yaml` lists the recipients:

- one age-plugin-yubikey recipient per YubiKey,
- each machine's SSH host key converted to age (`ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`),
- a per-machine age key for Home Manager (`age-keygen -y ~/.config/sops-nix/key.txt`).

`secrets/common.yaml` is shared by all hosts, `secrets/hosts/<host>.yaml` is per host, and
`secrets/users/<user>.yaml` is per user. After changing the recipients, re-encrypt the existing files with
`sops updatekeys <file>`. The dev shell provides `sops`, `age`, `age-plugin-yubikey` and `ssh-to-age`.

To create a file, write plaintext and encrypt it in place (`sops` can't open an empty file):

```sh
printf 'example: value\n' > secrets/common.yaml
sops encrypt --in-place secrets/common.yaml
sops secrets/common.yaml          # edit later; needs a YubiKey or the machine's key
```

### How secrets are wired

`modules/den/sops.nix` imports sops-nix for darwin, NixOS and Home Manager, and sets the defaults:

- **System:** each host's `sops.defaultSopsFile` is `secrets/hosts/<host>.yaml`, decrypted with the host's SSH
  key (`/etc/ssh/ssh_host_ed25519_key`).
- **Home Manager:** each user's `sops.defaultSopsFile` is `secrets/users/<user>.yaml`, decrypted with the key in
  `~/.config/sops-nix/key.txt`. Create it on each machine with `age-keygen -o ~/.config/sops-nix/key.txt` before
  the first switch.

Declare a secret in the aspect that uses it. Secrets in the per-host or per-user file need nothing more; secrets
from the common file need a `sopsFile`:

```nix
den.aspects.my-feature.os.sops.secrets.my_secret = { };
den.aspects.my-feature.os.sops.secrets.shared_secret.sopsFile = ../../secrets/common.yaml;
den.aspects.alberth.homeManager.sops.secrets.my_user_secret = { };
```

The decrypted value is at `config.sops.secrets.<name>.path`.

## Direnv

`.envrc` contains `use flake`, so with [direnv](https://direnv.net) the dev shell loads automatically in this
directory (run `direnv allow` once).

## Formatting

The formatter is `nixfmt` (the RFC 166 style):

```sh
git ls-files -z '*.nix' | xargs -0 -r nix fmt                                    # format
git ls-files -z '*.nix' | xargs -0 -r nix develop --command nixfmt --check       # check
```

## TODO

- Replace the placeholder age keys in `.sops.yaml` (`host_darwintron`, `host_nixostron`, `alberth_darwintron`,
  `alberth_nixostron` currently reuse magnus's keys), enable the matching recipients in the `common.yaml` and
  `alberth.yaml` rules, and run `sops updatekeys` on the secret files.
- Replace the example content in `secrets/*.yaml` with real secrets and declare them as `sops.secrets.<name>`.
- `nixostron`: add a root filesystem, a boot loader and `hardware-configuration.nix`, and confirm the platform.
- Fill in the empty `base` blocks and the per-host aspects.
- Build every host for real (`darwin-rebuild build`, `nixos-rebuild build`). `magnus` is already running a
  nix-darwin system from this flake; `darwintron` and `nixostron` have not been built yet.


## License

See [LICENSE](LICENSE).
