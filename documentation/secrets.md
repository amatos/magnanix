# Secrets

Secrets are managed with [nix-secrets](https://github.com/unnamed-systems/nix-secrets), which encrypts each one
to its own [age](https://age-encryption.org) file. The pieces live in two repos:

- **`amatos/secrets`** (private) holds the encrypted files, `<name>.enc`. magnanix reads it as its `secrets` flake
  input (`flake = false`). Keep a clone at `~/Developer/secrets` for editing.
- **magnanix** holds everything else: which secrets exist and who can decrypt each one
  ([`modules/den/_secrets-registry.nix`](../modules/den/_secrets-registry.nix)), and the aspects that use them.

A secret's name is its path in the storage without `.enc`: `common/<name>` for secrets shared between hosts,
`hosts/<host>/<name>`, `users/<user>/<name>`, and `bootstrap/<vm>/<name>` for the test VMs' private keys (read
only by the [VM scripts](testing-vms.md), never by a host).

## Recipients

The registry's `aliases` name every key that can decrypt something:

- `admins`: one age-plugin-yubikey recipient per YubiKey (`age-plugin-yubikey --list`). Every secret gets these.
- `host_<host>`: the host's SSH host key, as written in `/etc/ssh/ssh_host_ed25519_key.pub` (or
  `ssh-keyscan -t ed25519 <host>`). nix-secrets decrypts with the SSH key directly; no `ssh-to-age`.
- `<user>_<host>`: a per-machine age key for Home Manager, `age-keygen -y ~/.config/sops-nix/key.txt`. Create
  it on each machine with `mkdir -p -m 700 ~/.config/sops-nix && age-keygen -o ~/.config/sops-nix/key.txt`
  before the first switch. (The directory keeps its sops-nix name for now.)

Its `secrets` map each secret name to the aliases, besides `admins`, that can decrypt it. Keep each list to the
hosts or users that actually use the secret.

## Editing

From a magnanix checkout, inside `nix develop`, with a YubiKey plugged in:

```sh
secrets edit <name>       # create or change a secret, in $EDITOR
secrets decrypt <name>    # print it
secrets rekey             # re-encrypt everything after changing recipients in the registry
```

`secrets` is a wrapper around the nix-secrets CLI. It reads the recipients from the flake's `secretsAdmin`
output (built from the registry), writes to `~/Developer/secrets` (override with `NIX_SECRETS_STORAGE_PATH`), and
decrypts with the plugged-in YubiKeys (`yubikey-identities`; the preferred one alone when it's there).

Changes take effect once they're pushed and locked:

1. Commit and push `amatos/secrets`.
2. `nix flake update secrets` in magnanix, and commit `flake.lock`.
3. Deploy.

To try a change before pushing, point the input at the clone:
`apply-configuration --override-input secrets path:$HOME/Developer/secrets`. Use `path:`: as a plain path Nix
would read it as a git repo and skip files that aren't committed yet.

## Adding a secret

1. Add it to the registry with its recipients.
2. `secrets edit <name>`, then push `amatos/secrets` and `nix flake update secrets`.
3. Enable it in the aspect that uses it: system secrets in `os`/`darwin`/`nixos`, user secrets in `homeManager`:

   ```nix
   den.aspects.my-feature.os.security.nix-secrets.secrets."hosts/muninn/my_secret".enable = true;
   den.aspects.alberth.homeManager.security.nix-secrets.secrets."users/alberth/my_secret".enable = true;
   ```

   Use the decrypted file at `config.security.nix-secrets.secrets.<name>.path`. To embed a secret in a larger
   file, use a template: `security.nix-secrets.templates.<name>.content` with
   `${config.security.nix-secrets.secrets.<secret>}` where the value goes (see `modules/packages/mail.nix`).

Every registry secret is declared on every configuration, disabled. Enabling one that isn't in the locked
`secrets` input fails evaluation; to make a feature optional on that, test for the file with
`builtins.pathExists "${inputs.secrets}/<name>.enc"` (see `modules/packages/attic.nix`).

nix-secrets has no `restartUnits`. On NixOS, a unit that reads a secret gets
`restartTriggers = [ (config.local.nix-secrets.restartTrigger "<name>") ]`, a hash of the encrypted file, so it
restarts whenever the secret is edited or rekeyed.

## How secrets are wired

`modules/den/nix-secrets.nix` (in every host's includes) imports nix-secrets for darwin, NixOS and Home Manager,
with the storage and the registry from `modules/den/_nix-secrets-shared.nix`:

- **System:** decrypted with the host's SSH key (`/etc/ssh/ssh_host_ed25519_key`) to
  `/run/nix-secrets/secrets/<name>` (`/run/nix-secrets-for-users/…` for `neededForUsers`). Only root can read them
  unless the secret sets `owner`, `group` or `mode`. On macOS a launchd daemon does this, just after the switch.
- **Home Manager:** decrypted with `~/.config/sops-nix/key.txt` to
  `~/.local/share/nix-secrets/secrets/<name>`, which points into a per-session runtime directory.

On macOS the aspect carries two workarounds for bugs in nix-secrets v0.5.4 (a patch to the activation tool, and
the Home Manager launchd agent's arguments); see D8 in [NIX_SECRETS_PLAN.md](NIX_SECRETS_PLAN.md).

Hosts fetch the private input with the [GitHub token](#github-token-for-nix); CI with its own,
`SECRETS_REPO_TOKEN`. The test VMs have neither: their scripts send a copy of the locked storage and pass
`--override-input secrets path:<copy>`.

## alberth's password

`alberth`'s login password on NixOS is `common/alberth_password`, a yescrypt hash used as
`users.users.alberth.hashedPasswordFile`. It is declared with `neededForUsers`, so it is decrypted before the
accounts are created. Generate the hash with `nix shell nixpkgs#mkpasswd -c mkpasswd -m yescrypt` and paste it in
with `secrets edit common/alberth_password`. Any NixOS host `alberth` is on must be one of its recipients.

The flake's password takes priority. `base` sets `users.mutableUsers = false` on every NixOS host, so each switch
resets the password and `passwd` can't change it. Every user on a NixOS host therefore needs a password option or
SSH keys; `ephemeral` has the throwaway password `ephemeral` and darwintron-vm's access key (which nixostron-vm
uses too). macOS passwords are never managed here: nix-darwin has no password option, and
changing one with `dscl` breaks the login keychain and the FileVault token.

The password is for logging in, not for `sudo`. The `sudo` aspect (included by `base`) replaces sudo with sudo-rs
on NixOS, adds every user on the host to `wheel`, and sets `security.sudo-rs.wheelNeedsPassword = false` (the
NixOS default is `true`), so `wheel` members run sudo without a password. On macOS it enables Touch ID for sudo
instead.

## GitHub token for Nix

`common/github_secrets_repo_access_token` is a fine-grained GitHub token with read-only *Contents* access to the
private `amatos/secrets` repo. The `nix-access-tokens` aspect (on magnus, muninn, fortuna and tenabrae) renders it
as `access-tokens = github.com=<token>` in a template readable by root and the admin group (`wheel`, or `admin`
on macOS), which the Nix config `!include`s. It lets those hosts fetch the private repo and lifts GitHub's rate
limit for anonymous requests. Nix skips the `!include` when the file is missing or unreadable, so other users
(such as `nix-ssh` for remote builds) and a host that hasn't decrypted it yet still work, just without the token.
Until sops-nix is removed, the config also `!include`s the file sops-nix rendered before the cutover. CI uses
its own copy, the `SECRETS_REPO_TOKEN` Actions secret.

To rotate it: create a new token on GitHub, replace the value with
`secrets edit common/github_secrets_repo_access_token`, push and lock it, update `SECRETS_REPO_TOKEN`, deploy,
then revoke the old token.

## sops-nix (being removed)

Until the cleanup ([NIX_SECRETS_PLAN.md](NIX_SECRETS_PLAN.md), Phase 6), `.sops.yaml`, `secrets/` and the
sops-nix input stay in place so a rollback to a pre-cutover generation still works. Nothing reads them any more:
don't edit them.
