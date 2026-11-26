# Rex server

Every Linux host runs a personal [Rex](https://superlogical.com) server for each user, using
`den.aspects.rex-server` (`modules/packages/rex-server.nix`), which `base` includes. The Rex client is installed by
hand, not by this flake.

- **Source:** Rex's own prebuilt flake, the `rex` input, at `https://pkgs.superlogical.com/rex/nix/preview.tar.gz`.
  It is on the preview channel because stable has no releases yet. Neither nixpkgs nor Homebrew has Rex: their
  `rex` packages are (R)?ex, an unrelated Perl automation tool.
- **Mode:** per-user. The aspect turns on `services.rex` from the flake's home-manager module, a systemd user
  service named `rex` that runs `rex server run` as that user, listening on `$XDG_RUNTIME_DIR/rex`. This is what
  `rex server install` sets up on other distributions. The flake's NixOS module, with its shared server (`rex`
  account and group) and root login server, is not used.
- **Also installed:** the server turns on the module's `programs.rex`, which puts `rex` on the user's PATH and the
  `xterm-rex` terminfo in `~/.terminfo`. Its ssh guard, which stops `TERM=xterm-rex` reaching hosts that don't know
  it, is added to `~/.ssh/config` only for users with `programs.ssh.enable`. Others can run `rex terminfo setup`.
- **macOS:** nothing. The Rex app runs the server there, and the module refuses `services.rex` on Darwin.

The service starts at login and stops at logout. To keep it running while the user is logged out, run this once
as that user:

```sh
loginctl enable-linger
```

To check it: `systemctl --user status rex`, and `journalctl --user -u rex` for its logs.

## Updating

The channel URL always serves the newest preview release; `flake.lock` pins the exact one. The weekly input update
moves it along with everything else, or update it on its own:

```sh
nix flake update rex
```
