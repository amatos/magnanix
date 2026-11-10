# Secrets

Secrets are encrypted with [sops](https://github.com/getsops/sops) using age. `.sops.yaml` lists the recipients:

- one age-plugin-yubikey recipient per YubiKey,
- each machine's SSH host key converted to age (`ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`),
- a per-machine age key for Home Manager (`age-keygen -y ~/.config/sops-nix/key.txt`).

`secrets/common.yaml` is for secrets shared between hosts (`.sops.yaml` lists which hosts can decrypt it),
`secrets/hosts/<host>.yaml` is per host, `secrets/users/<user>.yaml` is per user, and
`secrets/bootstrap/darwintron.yaml` and `secrets/bootstrap/nixostron.yaml` hold the test VMs' private keys. After changing the recipients, re-encrypt the existing files with
`sops updatekeys <file>`. The dev shell provides `sops`, `age`, `age-plugin-yubikey` and `ssh-to-age`.

sops only uses a YubiKey when it is given the key's age-plugin-yubikey identity, so the dev shell sets
`SOPS_AGE_KEY_CMD="age-plugin-yubikey --identity"`: every `sops` run asks the plugin for the identities of the
YubiKeys plugged in at the time. Outside the dev shell, add them to sops's key file instead (the identity only
points at the key on the YubiKey, so it isn't secret):

```sh
age-plugin-yubikey --identity >> "$HOME/Library/Application Support/sops/age/keys.txt"   # macOS
age-plugin-yubikey --identity >> ~/.config/sops/age/keys.txt                               # Linux
```

To create a file, write plaintext and encrypt it in place (`sops` can't open an empty file):

```sh
printf 'example: value\n' > secrets/common.yaml
sops encrypt --in-place secrets/common.yaml
sops secrets/common.yaml          # edit later; needs a YubiKey or the machine's key
```

## How secrets are wired

`modules/den/sops.nix` imports sops-nix for darwin, NixOS and Home Manager, and sets the defaults:

- **System:** each host's `sops.defaultSopsFile` is `secrets/hosts/<hostName>.yaml` (so both nixostron hosts
  share `nixostron.yaml`), decrypted with the host's SSH
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

## alberth's password

`alberth`'s login password on NixOS is `alberth_password` in `secrets/common.yaml`, a yescrypt hash used as
`users.users.alberth.hashedPasswordFile`. It is declared with `neededForUsers`, so it is decrypted before the
accounts are created. Generate the hash with `nix shell nixpkgs#mkpasswd -c mkpasswd -m yescrypt` and paste
it in with `sops secrets/common.yaml`. Any NixOS host `alberth` is on must be a recipient of `common.yaml`.

The flake's password takes priority. `base` sets `users.mutableUsers = false` on every NixOS host, so each switch
resets the password and `passwd` can't change it. Every user on a NixOS host therefore needs a password option or
SSH keys; `ephemeral` has the throwaway password `ephemeral` and darwintron-vm's access key (which nixostron-vm
uses too). macOS passwords are never managed here: nix-darwin has no password option, and
changing one with `dscl` breaks the login keychain and the FileVault token.

The password is for logging in, not for `sudo`. The `sudo` aspect (included by `base`) replaces sudo with sudo-rs
on NixOS, adds every user on the host to `wheel`, and sets `security.sudo-rs.wheelNeedsPassword = false` (the
NixOS default is `true`), so `wheel` members run sudo without a password. On macOS it enables Touch ID for sudo
instead.
