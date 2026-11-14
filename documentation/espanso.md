# Espanso

[Espanso](https://espanso.org) is a cross-platform text expander: type a trigger such as `:date` and it is
replaced with the expansion. `den.aspects.espanso` (`modules/packages/espanso/espanso.nix`) installs it and starts it
at login (a launchd agent on macOS, a systemd user service on Linux). magnus and fortuna include it.

## Where matches live

Espanso loads every `*.yml` and `*.yaml` under `~/.config/espanso/match/`, recursively, except names that start
with `_`. Matches come from three places:

| Kind | Source | Ends up at | For |
|---|---|---|---|
| Public | `services.espanso.matches`: shared ones in the aspect, a user's own in their user aspect (`;;pgpkey` in `alberth.nix`, from `meta.gpgKey`) | `match/base.yml`, `match/<user>.yml` | anything fine to publish |
| Personal | a private git repo (`magnanix.espanso.repo`) | `match/personal`, a link to the checkout at `magnanix.espanso.dir` | everyday snippets |
| Secure | `secrets/users/<user>-espanso-<name>.yaml`, sops-encrypted | `match/<name>.yml` (a symlink) | account numbers, keys, anything that shouldn't be plaintext on GitHub |

A trigger must be unique across all three; Espanso warns about duplicates.

## Personal repo

Set the repo and where it's checked out in the user's Home Manager config. alberth's, in
`modules/users/alberth/alberth.nix`:

```nix
magnanix.espanso = {
  repo = "git@github.com:amatos/espanso-expansions.git";
  dir = "${config.home.homeDirectory}/Developer/espanso-expansions";
};
```

On hosts that run Espanso, Home Manager links `~/.config/espanso/match/personal` to `dir`, and activation clones
`repo` into `dir` if it doesn't exist, with the user's own git credentials. It never pulls, and if cloning fails
(no SSH agent yet, or Home Manager's systemd unit on NixOS) it only prints a warning with the `git clone` command
to run.

Day to day, edit the files in the checkout, commit and push, and `git pull` on the other machines. Espanso loads
files through the link but its file watcher doesn't see changes behind it, so run `espanso restart` after editing
(or after a pull). On machines Nix doesn't manage (Windows, for one), clone the repo into Espanso's `match` folder
by hand.

Keep only match files in the repo: Espanso would also try to load any other YAML, such as
`.github/workflows/*.yml`. Name a file with a leading `_` to keep Espanso from loading it.

## Secure matches

`den.aspects.espanso.secure` finds every `secrets/users/<user>-espanso-<name>.yaml` and has sops-nix decrypt each
one whole to `match/<name>.yml`; `alberth-espanso-street-address.yaml`, for example, becomes
`match/street-address.yml` (the sops secret itself is named `espanso-<name>.yml`: Espanso follows the symlink and
rejects a target without an extension). alberth gets it on magnus, from `den.aspects.magnus.provides.alberth`. Edit a file
from the dev shell, with a YubiKey plugged in:

```sh
sops secrets/users/alberth-espanso-street-address.yaml
```

To add a file without the plaintext ever touching the disk, pipe it to sops; new files need no Nix change, but
must be added to git before the flake can see them:

```sh
f=secrets/users/alberth-espanso-<name>.yaml
printf 'matches:\n  - trigger: ";;x"\n    replace: "..."\n' |
  sops encrypt --filename-override "$f" /dev/stdin > "$f"
git add "$f"
```

Then apply the configuration and run `espanso restart` (the symlink's target changes on each switch, which Espanso
does not always notice). sops encrypts the values, not the keys, so the public file shows how many matches there
are and roughly how long each value is, but not what they say. The file names (`<name>`) are public too.

`.sops.yaml` encrypts `secrets/users/alberth-*.yaml` to the same recipients as `alberth.yaml`, which includes only
magnus's user key. To use `secure` on another machine, add that machine's `alberth_<host>` key to the rule, run
`sops updatekeys` on each `secrets/users/alberth-espanso-*.yaml`, and include `den.aspects.espanso.secure` from the host's
`provides.alberth`.

## Match file format

All three use Espanso's match format:

```yaml
matches:
  - trigger: ":addr"
    replace: "1 Example Street"
  - trigger: ":sig"
    replace: |
      Regards,
      Someone
```

## Platform notes

- **macOS:** Espanso needs Accessibility permission (System Settings > Privacy & Security > Accessibility). The
  binary is in the Nix store, so macOS may ask again after an update changes its path.
- **Linux:** both the X11 and Wayland builds are installed, and a wrapper picks one from `$WAYLAND_DISPLAY`. The
  Wayland build reads keyboards from `/dev/input` and types through `/dev/uinput`, so the aspect enables
  `hardware.uinput` and adds the host's users to the `input` and `uinput` groups. Log out and in after the
  first switch for the groups to apply.
- The search bar opens with Alt+Space (Option+Space on macOS).
