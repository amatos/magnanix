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
| Secure | the encrypted secrets `users/<user>/espanso/<name>.yml` in `amatos/secrets` | `match/<name>.yml` (a symlink) | account numbers, keys, anything that shouldn't be plaintext on GitHub |

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

`den.aspects.espanso.secure` finds every `users/<user>/espanso/<name>.yml.enc` in the locked `secrets` input
(`amatos/secrets`, see [Secrets](secrets.md)) and has nix-secrets decrypt each one to `match/<name>.yml`;
`users/alberth/espanso/street-address.yml` becomes `match/street-address.yml`. The names keep `.yml` because
Espanso follows the symlink and rejects a target without an extension. alberth gets it on magnus, from
`den.aspects.magnus.provides.alberth`. Edit a file from the dev shell, with a YubiKey plugged in:

```sh
secrets edit users/alberth/espanso/street-address.yml
```

To add a file, first add its name to `modules/den/_secrets-registry.nix` with the same recipients as
`street-address.yml`. Then write it without the plaintext ever touching the disk by piping it in (`EDITOR=-`
makes `secrets edit` read the new value from standard input):

```sh
printf 'matches:\n  - trigger: ";;x"\n    replace: "..."\n' |
  EDITOR=- secrets edit users/alberth/espanso/<name>.yml
```

Then push `amatos/secrets`, run `nix flake update secrets`, apply the configuration and run `espanso restart` (the
symlink's target changes on each switch, which Espanso does not always notice). Only the file names (`<name>`)
are visible in magnanix's public registry; the private repo holds age files, which don't show the number or size
of the matches.

The registry gives `users/alberth/espanso/*` to alberth's key on magnus, muninn and fortuna (`alberth_<host>`). To
use `secure` on another machine, add that machine's key to those entries, run `secrets rekey`, push and lock, and
include `den.aspects.espanso.secure` from the host's `provides.alberth`.

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
- The search bar's shortcut (Alt+Space, Option+Space on macOS) is turned off with `search_shortcut = "off"` in
  `services.espanso.configs.default`.
