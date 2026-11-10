# Fastfetch

The `tui.fastfetch` feature (`modules/packages/fastfetch/`, included by `base`) installs
[fastfetch](https://github.com/fastfetch-cli/fastfetch) through Home Manager. Its config is written in Nix as
`programs.fastfetch.settings` and lands in `~/.config/fastfetch/config.jsonc`. It shows hardware, OS, uptime and
networking under boxed section banners. `bluetooth` (it crashed fastfetch 2.63.1 on Apple Silicon) and `publicip`
(a network call, and the IP shows in screenshots) are left commented out.

fastfetch runs when bash, zsh, fish or Nushell starts as an interactive login shell with stdout on a terminal: a new
terminal window or tab on macOS (editor terminals included, since they open login shells too) or an SSH session.
Each shell's hook is in its login file or checks for a login shell itself (`.zlogin`, `.bashrc` with
`shopt -q login_shell`, `config.fish` with `status is-login`, `login.nu`). Non-interactive shells (`ssh host cmd`,
scripts, agent shells) and non-login shells (nested shells, `exec fish`) stay quiet. To skip it, set
`FASTFETCH_ON_LOGIN=0` in the environment the shell starts with, such as a terminal's config.

`fastfetch` on `PATH` is a wrapper, `fastfetch-wrapper.py`, because fastfetch can't size the banners to its output.
The wrapper runs fastfetch twice:

1. Without the logo and in plain-text mode, to measure the widest data row.
2. Normally, inside a pseudo-terminal, then redraws every banner to that width.

It always prints something. If fastfetch crashes, hangs (30 s limit) or is interrupted part-way, the wrapper prints
what it got so far. If the normal run prints nothing, the wrapper falls back to the plain-text run. If both print
nothing, it reports fastfetch's exit status on stderr. `--help`, `--version`, `--list-*`, `--print-*` and
`--gen-config*` go straight to the real binary.

| Variable                  | Effect                                                                     |
| ------------------------- | -------------------------------------------------------------------------- |
| `FASTFETCH_CONFIG`        | config file to pass as `--config` (default: fastfetch's own lookup)        |
| `FASTFETCH_ON_LOGIN`      | `0` stops the shells from running fastfetch at login                       |
| `FASTFETCH_WRAPPER_DEBUG` | set to anything to log the wrapper's steps to stderr                       |

`FASTFETCH_BIN` (the real binary) is fixed to the store path by the package, so the wrapper can't call itself.

The wrapper's tests, `test_fastfetch_wrapper.py`, run every time the package builds; a failing test fails the
switch. Run them by hand with:

```sh
python3 -I modules/packages/fastfetch/test_fastfetch_wrapper.py
```
