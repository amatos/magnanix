# Plan: replace sops-nix with nix-secrets, secrets in `amatos/secrets`

## Status: 🚧 Phase 1 in review ([#127](https://github.com/amatos/magnanix/pull/127)); Phase 0 passed with workarounds

Phase 0 ran on the throwaway branch `spike/nix-secrets` (local, not merged); its results are under Phase 0 in §5,
and the macOS workarounds it needed are D8. Nothing else is implemented. Sections 1–2 evaluate
[nix-secrets](https://github.com/unnamed-systems/nix-secrets) against this flake; section 3 explains the
design decisions; sections 4–6 are the implementation and migration steps; section 7 records what was decided in
review.

Evaluated at nix-secrets `v0.5.4` (`c451d66`, 2026-11-21). Line references to nix-secrets are to that tree.

---

## 1. Recommendation

**Adopt it, but only after the Phase 0 spike passes, and pin the release.** nix-secrets fits this flake's
model (age, YubiKeys, SSH host keys, NixOS + nix-darwin + Home Manager, templates, `neededForUsers`), and moving
the ciphertext to the private `amatos/secrets` repo removes what `magnanix` (a **public** repo) leaks today:
`.sops.yaml`, the per-file recipient lists in every sops file, and which secret lives on which host.

It is a young project, though: four months old, two maintainers, `v0.5.x`. Four gaps affect this flake directly,
and the plan works around each one:

| Gap                                                                                     | Effect here                                                                                                         | Workaround in this plan                                                                         |
| --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| CLI reads **one** host's manifest ([#27](https://github.com/unnamed-systems/nix-secrets/issues/27)) | `rekey` from host A re-encrypts a shared secret to A's recipient list, which can drop host B, so B fails activation | A single recipient registry plus one "admin" manifest that holds every secret (§3 D1)            |
| No `restartUnits` ([#37](https://github.com/unnamed-systems/nix-secrets/issues/37))    | `atticd`, `attic-watch-store` and `postfix` aren't restarted when their secret changes                              | `restartTriggers` on the hash of the encrypted file (§3 D5)                                     |
| Host-to-secret mapping lives only in Nix                                                | `attic.nix` greps the sops file to see whether `attic_push_token` exists                                          | `builtins.pathExists` on the `.enc` file in the storage input                                   |
| Activation on macOS is broken in `v0.5.4` (found in Phase 0; [#9](https://github.com/unnamed-systems/nix-secrets/issues/9) closed as stale) | No secret activates on magnus or darwintron, system or Home Manager | A 5-line source patch and a launchd override, carried until upstream fixes them (§3 D8) |

If you'd rather not carry those workarounds, the alternative is to **keep sops-nix and only move `secrets/`
into `amatos/secrets` as a non-flake input** (the `sopsFile` paths change, nothing else does). That gets most of
the privacy benefit for a fraction of the work. §8 describes it in case Phase 0 fails.

---

## 2. Evaluation

### What fits

- **YubiKeys work.** The age crate is built with the `plugin` feature (`Cargo.toml`), and `extraPackages` exists
  specifically for `age-plugin-yubikey` (`nix/core/options/default.nix`). The six `age1yubikey1…` recipients
  carry over unchanged.
- **SSH host keys as identities.** NixOS and nix-darwin default `identityPaths` to the `services.openssh.hostKeys`
  ed25519/RSA keys (`nix/parts/identityPaths.nix`), so hosts keep decrypting with `/etc/ssh/ssh_host_ed25519_key`.
- **All three module systems.** NixOS (activation script, or systemd with userborn/sysusers), nix-darwin (a launchd
  daemon) and Home Manager (a systemd user service on Linux, a launchd agent on macOS).
- **Features in use here:** `neededForUsers` (alberth's password), templates (postfix's SASL table), custom `path`
  with symlinks (espanso match files), `owner` (`wireless_env`).
- **Private storage is the intended design.** `storage` is a path, and the docs recommend a private repo as a flake
  input (`storage = inputs.my-secrets + /storage`).
- **Fewer secrets in the public repo.** sops writes recipients and key names in plaintext; an age file names neither.
- **Builds with your nixpkgs.** It requires Rust ≥ 1.94; the pinned nixpkgs has 1.99.1 and age-plugin-yubikey 0.5.1.
- **Smaller tooling.** No `.sops.yaml`; recipients are Nix values, so a typo fails evaluation instead of
  encrypting to the wrong key.

### What doesn't (beyond the table in §1)

- **One file per secret.** sops YAML maps (`common.yaml` with 3 keys) become one `.enc` file each. That's 24 files
  instead of 13; it's also what makes per-secret recipients possible.
- **Scripting `edit` is awkward.** It needs `EDITOR=-` to read the value from stdin
  (`crates/nix-secrets-cli/src/utils/editor.rs`). The migration script relies on this.
- **`edit` writes plaintext to a temp file** (`$TMPDIR/.nix-secrets/secret_input_<name>_<pid>`) and removes it
  afterwards. sops does the same. On macOS `$TMPDIR` is per user.
- **`--identity` must be a regular file.** `get_identities` skips anything that isn't `is_file()`, so
  `-i <(age-plugin-yubikey --identity)` silently gives zero identities. The dev-shell wrapper writes a temp file
  instead (Phase 2).
- **Hostname guessing.** Without `#host`, the CLI uses `uname -n`, which on macOS can be `magnus.local`. The
  wrapper always passes an explicit configuration.
- **Activation on macOS is asynchronous** (launchd `RunAtLoad`). `darwintron-vm` already polls for its canaries,
  but anything that reads a secret *during* `darwin-rebuild` activation would race. Nothing does today.
- **Activation on macOS doesn't work at all in `v0.5.4`** without two workarounds (D8).
- **NixOS refuses to switch if any secret won't decrypt.** The module adds a pre-switch check
  (`nix-secrets-activate-check`) that decrypts every secret with the keys the machine has *before* activation.
  That's a useful guard against a forgotten rekey, but it means a host's identity must already be in place when
  the switch starts (it broke nixostron in Phase 0; see Phase 3).
- **Home Manager on nix-darwin needs `defaultGroup = "staff"`.** The default reads
  `osConfig.users.users.<user>.group`, which nix-darwin doesn't set.
- **Two-repo workflow for new secrets.** A host that enables a secret fails evaluation (the `missingSecrets`
  assertion) until the `.enc` file exists in the locked `secrets` input. See "Adding a secret" in Phase 5.
- **Known rough edges in issues:** activation failed without `age` in `extraPackages` (it's now in the default,
  #40/#10); a YubiKey with two slots can't be an *activation* identity (#32, which doesn't matter here: hosts
  activate with SSH keys, and YubiKeys are only used from the CLI); no duplicate-`path` check (#21).

---

## 3. Decisions to review

### D1. Single source of truth for recipients: a registry plus an admin manifest (recommended)

`nix-secrets edit` and `rekey` encrypt with the recipients from **the manifest of the configuration you point
`--flake` at**. That configuration only lists the secrets it enables, so `rekey` from one host can't see secrets
from another, and a secret two hosts share must get the same recipient list on both. Issue #10 reports exactly
this failure: activation broke unless the host had just been rekeyed.

Proposal:

- `modules/den/secrets-registry.nix` defines one attrset, `local.secrets.registry`, that maps each secret name to
  its recipients (aliases). It's the `.sops.yaml` replacement, keyed by secret instead of by file.
- The `nix-secrets` aspect declares **every** registry entry on every host with `enable = lib.mkDefault false` and
  `recipients = lib.mkForce (admins ++ entry.recipients)`. Aspects only set `enable = true` (plus `owner`, `path`
  and so on). Recipients therefore can't drift between hosts, and enabling a secret that isn't in the registry
  fails evaluation.
- A flake output, `secretsAdmin.<system>`, is a minimal configuration with nix-secrets enabled and **every**
  registry entry enabled. The CLI accepts any output name (`-m`) and evaluates
  `<output>.<name>.config.security.nix-secrets.manifest`, so `nix-secrets -m secretsAdmin -f .#aarch64-darwin rekey`
  rekeys everything consistently. That includes the VM bootstrap keys, which no host enables. It's one per system
  because the CLI builds the manifest with the local system's packages: a nix-darwin configuration on macOS, a
  NixOS one on Linux (as built in Phase 0).

When upstream ships manifest merging (#27), the admin output can go; the registry stays useful.

### D2. Host recipients: switch to `ssh-ed25519` public keys (recommended)

sops-nix converts the host SSH key to age internally, so `.sops.yaml` lists `ssh-to-age` output. nix-secrets
parses an SSH private key as an **age SSH identity**, which only matches `ssh-ed25519` stanzas, not X25519
stanzas encrypted to the converted key. Host recipients therefore become the hosts' `ssh-ed25519 AAAA…` public
keys. Sources:

| Host                    | Public key source                                                            |
| ----------------------- | ---------------------------------------------------------------------------- |
| magnus, muninn          | `ssh-keyscan -t ed25519 <host>` or `/etc/ssh/ssh_host_ed25519_key.pub`        |
| fortuna, tenabrae       | the same, or 1Password (the private halves are there)                         |
| darwintron, nixostron   | `ssh-keygen -y -f` on the decrypted `host_key` in `secrets/bootstrap/<vm>.yaml` |

The alternative, keeping the age recipients and putting an `ssh-to-age -private-key` copy of each host key in
`/var/lib/nix-secrets/identities.txt`, adds a second copy of every host's private key for no gain.

User keys (`alberth_magnus`, `alberth_muninn`, `ephemeral_*`) are already plain age keys and stay as they are.
Phase 2 adds a new one, `alberth_fortuna`.
Home Manager's `identityPaths` points at the existing `~/.config/sops-nix/key.txt` for now (Phase 6 moves it).

### D3. Where the registry lives: `magnanix` (decided)

- **In `magnanix`:** one place shows which host gets which secret, and adding a host is one commit plus a
  rekey. Recipient public keys and secret names stay public, as they are today in `.sops.yaml` (the names are
  public anyway, in every `sops.secrets.<name>` declaration).
- **In `amatos/secrets`** (with its own `flake.nix` exporting `registry`): hides the recipient topology too,
  but every host or recipient change spans both repos.

Decided: `magnanix`, which keeps today's exposure; moving it later is mechanical.

### D4. Fetching the private input: `github:` plus `access-tokens` (recommended)

Every host evaluates the flake itself (`deploy-magnanix` pulls and switches locally), and so do CI and the test
VMs. All of them need read access to `amatos/secrets`.

- **Recommended:** `inputs.secrets = { url = "github:amatos/secrets"; flake = false; }`, with a fine-grained PAT
  (read-only *Contents* on `amatos/secrets`) as `github_secrets_repo_access_token`, rendered into the Nix config as
  `access-tokens = github.com=<token>` and readable by root and the admin group. This was the
  [TODO](todo.md) item, and it also lifts GitHub's anonymous rate limit. To avoid a chicken-and-egg problem,
  Phase 1 wires it up with **sops-nix, before the cutover**.
- **Alternative:** `git+ssh://git@github.com/amatos/secrets`, which uses whatever SSH key the user has. That's
  zero-config on magnus (1Password agent) but needs a GitHub-authorised key on every other host, and a deploy key
  in CI.
- **Test VMs** get no credentials either way: the scripts ship a `git archive` of the secrets repo with the source
  and pass `--override-input secrets path:…` (Phase 4). Phase 0 confirmed this works.

Found in Phase 0: the `access-tokens` magnus has today can't read `amatos/secrets` (`github:` returns 404), so
Phase 1's token is still needed. Until then the spike used `git+https://github.com/amatos/secrets`, which Nix
fetches through git's credential helper (`gh` on magnus). That's a stopgap for magnus only.

### D5. Restarting services when a secret changes

There's no `restartUnits`. Each affected unit gets
`restartTriggers = [ (builtins.hashFile "sha256" "${storage}/<name>.enc") ]` through a small helper
(`local.secrets.restartTrigger "<name>"`). On NixOS the `activationScripts` method writes secrets before
`switch-to-configuration` restarts units, so the restart sees the new value. This affects:

- `atticd` (`atticd_env`)
- `attic-watch-store` (`attic_push_token`)
- `postfix` (the template, which needs the template content and `fastmail_smtp_password`)

The helper can be replaced if upstream adds #37.

### D6. Clean up recipients during the migration (decided: yes)

Today every secret in `common.yaml` goes to every host on that file's rule. Splitting the file allows narrower
lists, matched to which hosts actually use each secret:

- `common/alberth_password`: drop `host_magnus`. `.sops.yaml` says macOS hosts "can decrypt it but never use it".
- `common/certbot_luadns`: only magnus, muninn and fortuna include `certbot`; drop tenabrae.
- `common/github_secrets_repo_access_token`: every host that runs `deploy-magnanix` (magnus, muninn, fortuna, tenabrae).

- `users/alberth/*`: alberth's Home Manager secrets go to his user key on every machine that has one:
  `alberth_magnus`, `alberth_muninn` (it exists but isn't on the `alberth` rule today) and the new
  `alberth_fortuna`. This settles the first item in [todo.md](todo.md).

### D7. Bootstrap public keys: derive them instead of storing them (decided)

`host_key_pub` and `access_key_pub` are no longer stored at all, encrypted or plain. The scripts derive each one
from its private key with `ssh-keygen -y -f`, at the point where they need it. Storing them protects nothing:

- `access_key_pub` is already public, in `modules/users/ephemeral/ephemeral.nix` (`authorizedKeys`).
- `host_key_pub` becomes the `host_darwintron`/`host_nixostron` recipient in the public registry (D2).

Deriving keeps "nothing key-shaped in plaintext" without a second copy that could drift from the private key.
That leaves three bootstrap secrets per VM: `host_key`, `user_key` and `access_key`.

### D8. Carrying the macOS workarounds until upstream fixes them (found in Phase 0)

`v0.5.4` activates nothing on macOS. Two bugs, both still present on upstream `master`:

1. **The activation tool trips over its own marker file.** On Darwin, `nix-secrets-activate` mounts a RAM disk on
   the generations directory and marks it with a `nix-secrets-anchor` file. It then parses every entry in that
   directory as a generation number and fails on the marker (`Failed to parse generation: invalid digit found in
   string`, `crates/nix-secrets-activate/src/main.rs`, `init_generation_dir`). This hits both the nix-darwin
   daemon (`/run/nix-secrets.d`) and the Home Manager agent (`$(getconf DARWIN_USER_TEMP_DIR)/nix-secrets.d`).
   It's the bug in [#9](https://github.com/unnamed-systems/nix-secrets/issues/9), which was closed as stale
   without a fix.
2. **The Home Manager launchd agent can't start.** `nix/home-manager/activate/launchd.nix` sets the agent's
   `Program` to the whole command line. Home Manager quotes `Program` as one path, so launchd exits with 126.
   The nix-darwin daemon is fine: it uses nix-darwin's `command`, which runs through a shell.

Workarounds, in `modules/den/nix-secrets.nix`:

- `pkgs/patches/nix-secrets-skip-darwin-anchor.patch` skips the marker in `init_generation_dir`. It's applied
  to the activation package (`activate.package`) of the nix-darwin daemon and, on Darwin, of the Home Manager
  agent. Linux hosts keep the unpatched upstream package.
- On Darwin, the HM agent's `Program` is forced to `null` and the same command goes in `ProgramArguments`.

Removing them: when a release fixes #9, the patch stops applying and the darwin system **build** fails (CI only
evaluates darwin hosts, so it shows up in `darwintron-vm test` or on magnus, not in CI). Then drop the patch,
check whether the HM agent bug was fixed too, and rerun `darwintron-vm test`.

Upstream: the project's `CONTRIBUTING.md` doesn't accept LLM-assisted contributions, and both diagnoses and
patches here were made with an AI assistant. So they are not sent upstream as PRs. Reporting the bugs (or fixing
them yourself) is up to you.

---

## 4. Target layout

### `amatos/secrets` (private; currently only a README)

A plain directory tree, no `flake.nix` (`flake = false`). Secret name = path without `.enc`:

```text
README.md                         what this is, how to edit (points at magnanix documentation/secrets.md)
common/alberth_password.enc
common/certbot_luadns.enc
common/github_secrets_repo_access_token.enc
hosts/darwintron/canary.enc
hosts/fortuna/attic_push_token.enc
hosts/magnus/attic_push_token.enc
hosts/muninn/atticd_env.enc
hosts/muninn/attic_push_token.enc
hosts/muninn/fastmail_smtp_password.enc
hosts/nixostron/canary.enc
hosts/tenabrae/pihole_env.enc
hosts/tenabrae/wireless_env.enc
users/alberth/espanso/street-address.yml.enc
users/ephemeral/canary.enc
bootstrap/darwintron/{host_key,user_key,access_key}.enc
bootstrap/nixostron/{host_key,user_key,access_key}.enc
```

- The `*_pub` bootstrap values don't carry over; the scripts derive them (D7).
- `users/alberth.yaml` is empty today and doesn't carry over.
- `hosts/` is keyed by `hostName`, not the Den host name, so both nixostron hosts still share one directory.

### Secret mapping

`admins` = the six YubiKeys, added to every secret. `host_X` = X's `ssh-ed25519` key (D2).

| Old (file : key)                                  | New name                                | Recipients besides `admins`                         | Consumer                                                    |
| ------------------------------------------------- | --------------------------------------- | --------------------------------------------------- | ----------------------------------------------------------- |
| `common.yaml : alberth_password`                  | `common/alberth_password`               | host_muninn, host_fortuna, host_tenabrae (D6)       | `users/alberth/alberth.nix`, `neededForUsers`               |
| `common.yaml : certbot_luadns`                    | `common/certbot_luadns`                 | host_magnus, host_muninn, host_fortuna (D6)         | `packages/certbot.nix` (nixos and darwin)                   |
| `common.yaml : github_secrets_repo_access_token`  | `common/github_secrets_repo_access_token` | host_magnus, host_muninn, host_fortuna, host_tenabrae | new: Nix `access-tokens` (Phase 1)                          |
| `hosts/<h>.yaml : attic_push_token`               | `hosts/<h>/attic_push_token`            | host_<h>                                            | `packages/attic.nix` (magnus, muninn, fortuna)              |
| `hosts/muninn.yaml : atticd_env`                  | `hosts/muninn/atticd_env`               | host_muninn                                         | `packages/attic.nix`                                        |
| `hosts/muninn.yaml : fastmail_smtp_password`      | `hosts/muninn/fastmail_smtp_password`   | host_muninn                                         | `packages/mail.nix` template                                |
| `hosts/tenabrae.yaml : wireless_env`, `pihole_env` | `hosts/tenabrae/{wireless_env,pihole_env}` | host_tenabrae                                    | `hosts/tenabrae/tenabrae.nix`, `packages/pihole.nix`        |
| `hosts/{darwintron,nixostron}.yaml : canary`      | `hosts/<vm>/canary`                     | host_<vm>                                           | `hosts/virtual/*.nix`, VM scripts                           |
| `users/alberth-espanso-street-address.yaml` (whole file) | `users/alberth/espanso/street-address.yml` | alberth_magnus, alberth_muninn, alberth_fortuna (D6) | `packages/espanso/espanso.nix` (HM)                 |
| `users/ephemeral.yaml : canary`                   | `users/ephemeral/canary`                | ephemeral_darwintron, ephemeral_nixostron           | `hosts/virtual/*.nix` (HM)                                  |
| `bootstrap/darwintron.yaml : {host_key,user_key,access_key}` | `bootstrap/darwintron/*`     | alberth_magnus                                      | `pkgs/darwintron-vm.sh`                                     |
| `bootstrap/nixostron.yaml : {host_key,user_key,access_key}`  | `bootstrap/nixostron/*`      | alberth_magnus, alberth_muninn                      | `pkgs/nixostron-vm.sh`                                      |
| `bootstrap/<vm>.yaml : {host_key_pub,access_key_pub}`        | not migrated (D7)            |                                                     | derived with `ssh-keygen -y -f`                             |

The espanso name keeps a `.yml` suffix because Espanso resolves the symlink and rejects match files without an
extension (the same reason as today).

---

## 5. Implementation phases

Each phase is a separate branch/PR, so sops-nix keeps working until the cutover (Phase 4) lands, and that cutover
is a single commit you can roll back.

### Phase 0: spike on the test VMs (go/no-go)

On a throwaway branch, with a scratch storage directory in `magnanix` (no private input yet), wire nix-secrets for
only the three canaries, then run `darwintron-vm test <branch>` and `nixostron-vm test <branch>`. It passes if:

1. Both system canaries and the Home Manager canary decrypt (nix-darwin launchd daemon, NixOS activation script,
   HM launchd agent and systemd user service).
2. darwin evaluation works with Determinate (`installPackage = false` on hosts, so the module's
   `config.nix.package or null` default for the CLI is never forced; see `nix/core/env.nix`).
3. `secretsAdmin.<system>` evaluates and `nix-secrets -m secretsAdmin -f .#<system> edit|decrypt|rekey` works with a
   YubiKey identity from `age-plugin-yubikey --identity`, with one key plugged in and with the others absent.
4. Host decryption works with an `ssh-ed25519` recipient and `/etc/ssh/ssh_host_ed25519_key` as the identity
   (D2).
5. `--override-input secrets path:…` works through `apply-configuration` and `nixos-rebuild`.

If any of these fails and has no workaround, stop and use §8.

**Result (2026-11-22): all five pass, with workarounds.** Final run on `spike/nix-secrets` at `79b840b`:
`darwintron-vm test` and `nixostron-vm test` both passed. On both VMs, every canary (sops-nix and nix-secrets,
system and Home Manager) decrypted after a reboot, and on darwintron also right after the switch. Both rolled back
cleanly.

| Check | Result |
| ----- | ------ |
| 1. Canaries decrypt | ✅ with the two macOS workarounds (D8); NixOS needed none |
| 2. darwin evaluates under Determinate | ✅ (HM on darwin needs `defaultGroup = "staff"`) |
| 3. Admin CLI with a YubiKey | ✅ `decrypt` and `rekey` with 13125942; rekeyed files still open with the VMs' keys |
| 4. SSH host key as identity | ✅ on both VMs, no `ssh-to-age` |
| 5. `--override-input` | ✅ the flake's `secrets` input pointed at `amatos/secrets` (README only) and the guests had no credentials, so the canaries could only come from the shipped copy |

What the spike built, to carry into Phases 2–4 (the code is on `spike/nix-secrets`):

- `modules/den/_versions.nix`: the nix-secrets tag (`nix-secrets = "v0.5.4";`); the input URL is built from it.
- `modules/den/_secrets-registry.nix` (aliases and per-secret recipients) and `_nix-secrets-shared.nix` (the
  `security.nix-secrets` settings every configuration and `secretsAdmin` share). Plain `import`s rather than a
  `local.secrets.registry` option: simpler, and they're needed outside the module system by `secretsAdmin`.
- `modules/den/nix-secrets.nix`: the `nix-secrets` aspect with a nested `nix-secrets.home`, and the D8
  workarounds.
- `secretsAdmin.<system>` and the `secrets` wrapper in `modules/flake/outputs.nix`.
- A `yubikey-identities` helper in the dev shell, used by both `secrets` and sops (`SOPS_AGE_KEY_CMD`). With
  several YubiKeys plugged in, the plugin tries them in its own order and picked 32146072 (PIN and touch)
  first. The helper returns only 13125942's identity (no PIN, no touch) when it's plugged in, and every key's
  otherwise. `YUBIKEY_PREFERRED_SERIAL` overrides the choice.
- `apply-configuration` passes extra arguments through to `darwin-rebuild` / `nixos-rebuild`.
- The VM scripts' override wiring (Phase 4).

Found on the way and fixed on `main`: `wait_for_ssh` in both VM scripts could hang forever at a password prompt
(#124, `BatchMode=yes`).

### Phase 1: GitHub token, still on sops-nix (independent of nix-secrets)

Done first so every host can fetch a private input before the cutover needs it.

1. ✅ Create a fine-grained PAT: read-only *Contents* on `amatos/secrets` (public repos are readable anyway). Put
   it in `common.yaml : github_secrets_repo_access_token` (`sops secrets/common.yaml`). The older, unused
   `github_access_token` in the same file stays until it's removed and revoked ([TODO](todo.md)).
2. ✅ New aspect `modules/packages/nix-access-tokens.nix` ([#127](https://github.com/amatos/magnanix/pull/127)),
   included by magnus, muninn, fortuna and tenabrae, not by `base`: the test VMs can't decrypt `common.yaml`. A
   sops template renders `access-tokens = github.com=<placeholder>`, readable by root and the admin group
   (`wheel` on NixOS, `admin` on macOS, mode `0440`), and the Nix config `!include`s its path:
   `nix.extraOptions` on NixOS, `environment.etc."nix/nix.custom.conf".text = lib.mkAfter …` on macOS. Nix
   skips an `!include` that is missing or unreadable, so a host without the secret and other users such as
   `nix-ssh` still work.
3. ✅ Add a CI secret `SECRETS_REPO_TOKEN` (the same PAT or a separate one) to `amatos/magnanix`.
4. Deploy to every host (`update-all-magnanix`), then confirm on each one:
   `nix flake metadata github:amatos/secrets`. It fetches the repo and then reports that `flake.nix` doesn't
   exist, which is expected: the repo isn't a flake.

### Phase 2: create the storage in `amatos/secrets`

Do this on magnus with a YubiKey. Nothing in `magnanix` changes behaviour yet: the registry and admin output
are added, but no host enables nix-secrets.

1. **Collect host public keys** (D2) into the registry's aliases.
2. **Create `alberth_fortuna`** (D6). On fortuna, as alberth:
   `age-keygen -o ~/.config/sops-nix/key.txt` (the same path as the other machines until Phase 6), then
   `age-keygen -y ~/.config/sops-nix/key.txt` for the public half. Back the private key up in 1Password next to
   fortuna's host key.
3. **Add to `magnanix`** (one PR, no host changes):
   - flake-file inputs, in `modules/den/nix-secrets.nix` (Phase 3 fills in the rest of that file;
     `nix run .#write-flake` regenerates `flake.nix`). The tag lives in `modules/den/_versions.nix`
     (`nix-secrets = "v0.5.4";`), as in the spike:
     ```nix
     flake-file.inputs.nix-secrets = {
       url = "github:unnamed-systems/nix-secrets/${versions.nix-secrets}";
       inputs.nixpkgs.follows = "nixpkgs";
     };
     flake-file.inputs.secrets = { url = "github:amatos/secrets"; flake = false; };
     ```
   - `modules/den/_secrets-registry.nix` (aliases: admins, `host_*`, user keys; and per-secret recipients from the
     mapping table) and `_nix-secrets-shared.nix`, from the spike.
   - `secretsAdmin.<system>` in `modules/flake/outputs.nix` (D1), from the spike: nix-secrets with every registry
     entry enabled, `activate.enable = false`, `installPackage = false`, `identityPaths = [ ]`.
   - Dev shell, from the spike: `inputs.nix-secrets.packages.${system}.nix-secrets` with `age-plugin-yubikey` in
     its `extraPackages`, the `yubikey-identities` helper, and a `secrets` wrapper that:
     - writes `yubikey-identities` to a `mktemp` file and removes it on exit,
     - runs `nix-secrets --module-system secretsAdmin --flake "$repo#<system>" --identity "$tmp" "$@"`,
     - defaults `NIX_SECRETS_STORAGE_PATH` to `~/Developer/secrets` (overridable; the spike used
       `./secrets-spike`).
   - `SOPS_AGE_KEY_CMD = "yubikey-identities"`, so sops picks the same YubiKey.
   - Keep `sops` in the dev shell until Phase 6.
   - `.github/workflows/update-flake-lock.yml`: the release-tag bump from §6. It ships in this PR because this
     is where the pinned input first appears, so a release that lands mid-migration is still picked up.
4. **Clone** `amatos/secrets` to `~/Developer/secrets`.
5. **Migrate the values** with a script in the dev shell (one-off, not committed to `magnanix`). For each row of the
   mapping table it pipes the sops value straight into nix-secrets, so plaintext never touches the repo:
   ```sh
   export EDITOR=-
   # key in a map:
   sops -d --extract '["certbot_luadns"]' secrets/common.yaml | secrets edit common/certbot_luadns
   # whole file (espanso):
   sops -d secrets/users/alberth-espanso-street-address.yaml | secrets edit users/alberth/espanso/street-address.yml
   ```
   Check whether `sops -d --extract` adds a trailing newline for multi-line values such as `atticd_env` and
   `wireless_env`; the round-trip check in the next step catches any difference.
6. **Verify the round trip** for every secret:
   `cmp <(sops -d --extract …) <(secrets decrypt <name>)`. Also run `age-plugin-yubikey` with a *second* YubiKey
   on one secret to confirm all six are recipients.
7. **Commit and push** `amatos/secrets`, then run `nix flake update secrets` in `magnanix`.

### Phase 3: rewrite the consumers (the cutover PR, part 1)

All of Phases 3 and 4 land as one PR. Mechanical changes per file:

| File                                    | Change                                                                                                                                                                                        |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `modules/den/sops.nix` → `nix-secrets.nix` | Start from the spike's aspect: the module imports, `storage = inputs.secrets`, `installPackage = false`, registry injection (D1), `identityPaths` (host key; HM: `~/.config/sops-nix/key.txt`), HM `defaultGroup = "staff"` on darwin, and the D8 workarounds. Add `extraPackages = [ pkgs.age ]` and the `restartTrigger` helper (D5). |
| `users/alberth/alberth.nix`             | `security.nix-secrets.secrets."common/alberth_password" = { enable = true; neededForUsers = true; }`, and `hashedPasswordFile = ….path`.                                                     |
| `packages/certbot.nix` (both platforms) | Enable `common/certbot_luadns` and use its `.path`. Update the `/run/secrets/certbot_luadns` comment.                                                                                       |
| `packages/attic.nix`                    | `hasToken = builtins.pathExists "${inputs.secrets}/hosts/${hostName}/attic_push_token.enc"`; enable `hosts/${hostName}/attic_push_token` and `hosts/muninn/atticd_env`; `restartTriggers` (D5). |
| `packages/mail.nix`                     | `security.nix-secrets.templates.postfix-sasl-passwords.content = "… ${secrets."hosts/muninn/fastmail_smtp_password"}\n"`; `restartTriggers` on postfix.                                     |
| `packages/pihole.nix`, `hosts/tenabrae/tenabrae.nix` | Enable and use `.path`; keep `owner` for `wireless_env`.                                                                                                                                   |
| `packages/espanso/espanso.nix`          | `readDir "${inputs.secrets}/users/${user}/espanso"`, keep `*.yml.enc`, enable each with `path = "${xdg.configHome}/espanso/match/<name>.yml"`.                                              |
| `packages/nix-access-tokens.nix`        | Port the template; `!include` **both** the old (`/run/secrets/…`) and new (`/run/nix-secrets/templates/…`) paths for one release so rollback keeps fetching.                                |
| `hosts/virtual/{darwintron,nixostron}.nix` | Enable the canaries; give them an explicit `path` so the scripts don't depend on defaults.                                                                                                 |
| `hosts/virtual/nixostron.nix`           | The `nixostron-keys` activation script installs the user key where HM's `identityPaths` looks (unchanged path for now), and must run before `nixSecretsActivate`. Also add the staged `/var/lib/nixostron-keys/host_key` to `identityPaths`: the pre-switch check runs before that script installs the host key in `/etc/ssh` (missing paths are skipped). Done in the spike. |
| `packages/openssh.nix`, `hosts/*/` comments | Replace "sops-nix decrypts with" in comments.                                                                                                                                                |

### Phase 4: scripts, CI, docs (the cutover PR, part 2)

- **`pkgs/darwintron-vm.sh`, `pkgs/nixostron-vm.sh`:**
  - read bootstrap keys with `secrets decrypt bootstrap/<vm>/<key>` (or `age -d -i ~/.config/sops-nix/key.txt
    "$secrets_repo/bootstrap/<vm>/<key>.enc"`, which needs no Nix evaluation);
  - derive `host_key.pub` and `access_key.pub` with `ssh-keygen -y -f` instead of decrypting them (D7). That
    covers darwintron-vm's `/etc/ssh/ssh_host_ed25519_key.pub` and `authorized_keys` writes, and
    nixostron-vm's staged key files, which `nixostron.nix`'s `nixostron-keys` script installs;
  - replace `expected_recipient` (which greps `.sops.yaml`) with `nix eval --raw "$work/src#secretsAdmin.<system>.config.security.nix-secrets.recipientAliases.host_<vm>"`;
  - ship `git archive` of the locked secrets rev with the source and pass `--override-input secrets path:<dir>` to
    `apply-configuration`, `nixos-rebuild` and `nixos-anywhere` (D4). The spike already does this for the
    `test` path, shipping `./secrets-spike` instead of the secrets repo: darwintron to `~/Developer/secrets`,
    with the override on both `nix develop` and `apply-configuration`; nixostron to `~/secrets`, with the
    override on `nixos-rebuild switch`. Still to do: `nixos-anywhere` (the baseline install, which runs on magnus
    and would otherwise fetch the input itself), and finding out whether `nix develop` really needs the override
    (the spike passed it to be safe);
  - change the canary paths;
  - update the script tests (`test-scripts`).
- **`.github/workflows/build.yml`, `update-flake-lock.yml`:** pass
  `access-tokens = github.com=${{ secrets.SECRETS_REPO_TOKEN }}` to Nix (via `NIX_CONFIG` or the installer
  action's `extra-conf`) in every job that evaluates. `update-flake-lock` then also bumps `secrets`, and the
  nix-secrets release tag ("Keeping nix-secrets on the latest release" below).
- **Docs:** rewrite `documentation/secrets.md`; update `adding-hosts-and-users.md` ("add the host to the registry,
  then `secrets rekey`"), `architecture.md`, `espanso.md`, `binary-cache.md`, `mail.md`, `tenabrae.md`,
  `testing-vms.md`, `tls-certificates.md`, `todo.md`, and the README table.
  - **Adding a secret** becomes: add it to the registry → `secrets edit <name>` → push `amatos/secrets` →
    `nix flake update secrets` → enable it in the aspect. For local iteration before pushing, use
    `--override-input secrets ~/Developer/secrets`.
- **Rollout order** after CI passes: `darwintron-vm test` and `nixostron-vm test` on the branch → merge →
  magnus → muninn (services; check `atticd`, `postfix` and `attic-watch-store`) → fortuna → tenabrae. On each:
  `ls -l /run/nix-secrets/secrets/...`; on NixOS hosts also log in with the password.
- **Rollback:** `darwin-rebuild --rollback` or `nixos-rebuild switch --rollback`. The previous generation still has
  sops-nix and its encrypted files in the store, and Phase 1's token is still included from its old path.

### Phase 5: soak

Keep sops-nix's files and input in place (rollback depends on them) for a week or two of normal deploys. Include
at least one `secrets rekey` and one secret change on muninn, to exercise D5.

### Phase 6: cleanup

- Remove the `sops-nix` input, `.sops.yaml`, `secrets/`, `sops` and `ssh-to-age` from the dev shell, the
  `SOPS_AGE_KEY_CMD` env, and the old `!include` path.
- Move HM identities from `~/.config/sops-nix/key.txt` to nix-secrets' default
  `~/.config/nix-secrets/identities.txt` (copy the file on each machine, update the VM scripts and `identityPaths`).
  No rekey is needed: the key doesn't change.
- Optional: the old sops files stay in `magnanix`'s public git history. They're encrypted, but if you want the
  migrated values to have never been public even as ciphertext, rotate them (`secrets edit`) after the cutover.

---

## 6. Keeping nix-secrets on the latest release

The input is pinned to a tag (`nix-secrets = "v0.5.4";` in `modules/den/_versions.nix`, which builds the URL), so
`nix flake update` alone never moves it to a new release. The weekly `update-flake-lock` workflow does the bump
(it ships in the Phase 2 PR). That workflow already opens a PR that gets a full CI build and a
`darwintron-vm test` checklist. Three changes to `.github/workflows/update-flake-lock.yml`:

1. A new step **before** "Update flake.lock", so the lock and `write-flake` see the new tag:

   ```yaml
   # nix-secrets is pinned to a release tag, which `nix flake update` never moves.
   # Stable tags only (vX.Y.Z), so release candidates are skipped.
   - name: Bump nix-secrets to its latest release tag
     id: nix-secrets
     run: |
       file=modules/den/_versions.nix
       old=$(sed -nE 's/^ *nix-secrets = "(v[0-9]+\.[0-9]+\.[0-9]+)";.*/\1/p' "$file")
       # Assigned on their own lines so a failing command stops `bash -e`.
       tags=$(git ls-remote --tags --refs https://github.com/unnamed-systems/nix-secrets)
       new=$(sed 's|.*refs/tags/||' <<<"$tags" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)
       [ -n "$old" ] && [ -n "$new" ] || { echo "::error::could not read the nix-secrets tags"; exit 1; }
       sed -i -E "s/^( *nix-secrets = \")v[0-9]+\.[0-9]+\.[0-9]+(\";)/\1$new\2/" "$file"
       echo "old=$old" >> "$GITHUB_OUTPUT"
       echo "new=$new" >> "$GITHUB_OUTPUT"
       echo "nix-secrets: $old -> $new"
   ```

2. In "Write the pull request body", a section that only appears when the tag moved:

   ```bash
   if [ "${{ steps.nix-secrets.outputs.old }}" != "${{ steps.nix-secrets.outputs.new }}" ]; then
     echo
     echo 'nix-secrets: `${{ steps.nix-secrets.outputs.old }}` → `${{ steps.nix-secrets.outputs.new }}`'
     echo "([changes](https://github.com/unnamed-systems/nix-secrets/compare/${{ steps.nix-secrets.outputs.old }}...${{ steps.nix-secrets.outputs.new }}))"
     echo
     echo '- [ ] Read the nix-secrets changes; on a minor bump also run `nixostron-vm test update-flake-lock`'
     echo '- [ ] If `darwintron-vm test` fails to build the nix-secrets patch, upstream may have fixed #9: see D8'
   fi
   ```

3. `modules/den/_versions.nix` added to the "Create or update pull request" step's `add-paths`.

The tag lookup and both `sed` commands were checked (GNU sed, as on the Ubuntu runner) against the real tags and
the spike's `_versions.nix`: they read `v0.5.4` and rewrite only the `nix-secrets` line.
The workflow itself first runs after the Phase 2 PR merges; start it by hand once (`workflow_dispatch`) to check it.

Why not the alternatives:

- **GitHub "Watch → Releases":** the project publishes tags but no GitHub Releases (the releases API returns
  none), so it would never notify you.
- **Renovate or Dependabot:** neither bumps a ref inside a flake URL, and `flake.nix` is generated by flake-file
  anyway; the URL lives in the module.

While the project is pre-1.0, a minor bump (`0.5` to `0.6`) can change options. Read the compare link before
merging, and run `nixostron-vm test` as well as darwintron for those.

---

## 7. Decisions recorded in review

| Question                          | Decision                                                                                     |
| --------------------------------- | -------------------------------------------------------------------------------------------- |
| Adopt nix-secrets?                | Yes, after Phase 0 passes, pinned to a release tag                                            |
| D1, D2, D4, D5                    | As recommended                                                                               |
| D3: where the registry lives      | `magnanix`                                                                                   |
| D6: trim recipients               | Yes: magnus off `alberth_password`, tenabrae off `certbot_luadns`                             |
| Bootstrap `*_pub` keys            | Not stored; derived from the private keys (D7)                                                |
| Pinning                           | Release tags, bumped weekly by `update-flake-lock` (§6)                                       |
| `alberth_fortuna`                 | Created during the migration (Phase 2, step 2), and a recipient of alberth's HM secrets (D6)  |
| Phase 0                           | Passed with the D8 workarounds; go ahead with Phase 1                                         |
| Preferred YubiKey                 | 13125942 when plugged in, for both `secrets` and sops (`yubikey-identities`)                  |
| Upstream fixes for D8             | No AI-prepared PRs (upstream policy); reporting them is up to you                             |

---

## 8. Fallback: keep sops-nix, move only the ciphertext

If Phase 0 fails: Phase 1 as written, then move `secrets/` and `.sops.yaml` to `amatos/secrets` unchanged, add
`inputs.secrets` (`flake = false`), and replace `../../secrets/…` with `"${inputs.secrets}/…"` in `sops.nix`,
`alberth.nix`, `certbot.nix`, `espanso.nix` and `attic.nix`. Phase 4's CI token and VM `--override-input` steps
apply unchanged. This takes the ciphertext, recipient lists and key names out of the public repo; you keep sops's
per-file recipients, `sops updatekeys`, and plaintext key names inside the private repo.
