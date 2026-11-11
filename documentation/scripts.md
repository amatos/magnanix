# Scripts

`alberth`'s scripts live in `modules/users/alberth/scripts/`. The `alberth.scripts` aspect
(`modules/users/alberth/scripts.nix`) installs them into `~/.local/bin` and puts that directory on `PATH`. Home
Manager's zsh sets `PATH` in `.zshenv`, so the scripts also run over non-interactive SSH (`ssh host cmd`). To add a
script, put it in the directory, add a `home.file` entry for it in `scripts.nix`, and add tests beside it (see
[Testing scripts](testing-scripts.md)).

`deploy-magnanix` is installed in `~/.local/bin` as well, but it is built in Nix
(`modules/users/alberth/deploy-magnanix.nix`); see [Applying and updating](applying.md).

| Script                | What it does                                                                     |
| --------------------- | -------------------------------------------------------------------------------- |
| `control-dock.sh`     | turns Dock autohide on or off (macOS)                                            |
| `dollar.sh`, `$`      | runs its arguments, so a pasted `$ cmd` works                                    |
| `extract.sh`          | extracts an archive, or mounts a disk image, based on its extension              |
| `switch-yubikey`      | points gpg's key stubs at the YubiKey that is plugged in now                     |
| `update-all-magnanix` | runs `deploy-magnanix` on every host in parallel                                 |
| `velja-open.sh`       | `open "$@"`, for the Velja browser picker (macOS)                                |
| `yubi-disable`        | turns off the OpenPGP USB interface of YubiKey 32146072, which lives in magnus   |
| `yubi-enable`         | turns that interface back on and has gpg relearn the card                        |

## control-dock.sh

`control-dock.sh -h` hides the Dock (turns autohide on); `control-dock.sh -s` shows it (turns autohide off). It
changes the setting through System Events with `osascript`, so it only works on macOS. With no option, or an
unknown one, it prints its usage and exits 1.

## dollar.sh

Runs its arguments as a command, after printing a short reminder to stop pasting commands. It is also installed as
`~/.local/bin/$`, so a pasted `$ somecommand` runs `somecommand` instead of failing with `$: command not found`.

This works in bash and zsh. It is a file on `PATH` rather than a shell alias because bash doesn't allow `$` in an
alias name. fish and Nushell treat a leading `$` as the start of a variable, so `$ somecommand` is a syntax error
there.

## extract.sh

`extract.sh <file>` picks a tool by the file's extension and unpacks the file into the current directory:

| Extension           | Tool                                       |
| ------------------- | ------------------------------------------ |
| `.tar.bz2`, `.tbz2` | `tar -jxvf`                                |
| `.tar.gz`, `.tgz`   | `tar -zxvf`                                |
| `.tar`              | `tar -xvf`                                 |
| `.bz2`              | `bunzip2`                                  |
| `.gz`               | `gunzip`                                   |
| `.zip`, `.ZIP`      | `unzip`                                    |
| `.rar`              | `unrar x`                                  |
| `.Z`                | `uncompress`                               |
| `.pax`, `.pax.Z`    | `pax -r` (after `uncompress` for `.pax.Z`) |
| `.dmg`              | `hdiutil mount` (macOS)                    |

It exits 1 with an error if it gets no file or more than one, if the file doesn't exist, or if it doesn't know the
extension. `bunzip2`, `gunzip` and `uncompress` replace the compressed file with the uncompressed one.

## switch-yubikey

Both YubiKeys hold the same GPG keys, but gpg's key stubs point at only one card, so gpg asks for that card even
when the other one is plugged in. `switch-yubikey` asks you to insert the key you want to use, waits for Enter, and
runs `gpg-connect-agent "scd serialno" "learn --force" /bye`, which points the stubs at the inserted card. The
comment at the top of the script describes how the keys were copied to both YubiKeys.

## update-all-magnanix

Deploys the whole fleet: it runs `deploy-magnanix` on fortuna, magnus and muninn in parallel. See
[Applying and updating](applying.md) for how it reaches each host and how it reports failures.

## velja-open.sh

Runs `open "$@"`. It is meant for Velja, the macOS browser picker installed by the `macos.velja` aspect
(`modules/packages/appstore/velja.nix`, included on magnus). Velja's own settings aren't managed in this repo.

## yubi-enable and yubi-disable

YubiKey 32146072 lives permanently in magnus. These two scripts turn its OpenPGP USB interface off and back on,
without unplugging the key:

- `yubi-disable` runs `ykman -d 32146072 config usb -d openpgp -f`, which turns the interface off, and prints
  `OpenPGP interface of YubiKey 32146072 disabled`.
- `yubi-enable` runs `ykman -d 32146072 config usb -e openpgp -f`, which turns it back on, and prints
  `OpenPGP interface of YubiKey 32146072 enabled`. Then it runs
  `gpg-connect-agent "scd serialno" "learn --force" /bye`, like `switch-yubikey`, so gpg's key stubs point at
  this key again.

Both take `ykman` from `PATH`; the `tui.yubikey` aspect installs it. Without it they exit 1 with
`ykman not found`. If `ykman` fails (for example, the key isn't plugged in), they exit 1 with
`ykman failed to enable OpenPGP` or `ykman failed to disable OpenPGP`, and `yubi-enable` skips the gpg step.
