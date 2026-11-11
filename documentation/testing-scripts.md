# Testing scripts

`test-scripts` lints and tests the repo's shell and Python scripts. Run it from the dev shell:

```sh
nix develop --command test-scripts
```

CI runs the same command as the `script-tests` flake check, on Linux and macOS, in the Evaluate tier of
`.github/workflows/build.yml`. To run the check locally:

```sh
nix build --no-link --print-build-logs .#checks.aarch64-darwin.script-tests
```

The command is `pkgs/test-scripts.sh`, packaged in `modules/flake/outputs.nix`. It finds its targets by itself, so new
scripts and tests are picked up without registering them anywhere:

| What                         | Which files                                       | Tool                                  |
| ---------------------------- | ------------------------------------------------- | ------------------------------------- |
| Shell lint                   | files with an `sh` or `bash` shebang, `pkgs/*.sh` | shellcheck                            |
| zsh syntax                   | files with a `zsh` shebang                        | `zsh -n` (parse only)                 |
| Shell tests                  | `*.bats`                                          | [bats](https://bats-core.readthedocs.io) |
| Python tests                 | `test_*.py`                                       | `python3 -I <file>` (stdlib unittest) |
| Python lint and formatting   | `*.py`                                            | `ruff check`, `ruff format --check`   |

It runs every section even after one fails, and exits non-zero if any failed.

## Writing tests

Keep a script's tests next to it, named after it: `update-all-magnanix.bats` beside `update-all-magnanix`,
`test_fastfetch_wrapper.py` beside `fastfetch-wrapper.py`. A test file may cover a few related scripts
(`yubi.bats` covers `yubi-enable` and `yubi-disable`).

- **Shell:** stub the commands the script calls (ssh, sudo, hostname, ...) with small executables on `PATH`, and
  record their calls to a file the test can check. See `modules/users/alberth/scripts/update-all-magnanix.bats`.
  Start stubs with `#!$BASH`, not `#!/usr/bin/env bash`: the Linux build sandbox has no `/usr/bin/env`. Run
  the script under test through its interpreter (`bash "$SCRIPT"`, `sh "$SCRIPT"`) for the same reason. To run one file while working on it:
  `nix shell nixpkgs#bats nixpkgs#procps -c bats path/to/file.bats`.
- **Python:** use the standard library's `unittest`, so the tests need nothing beyond `python3`. The file must run
  on its own (`unittest.main()` at the end) and exit non-zero on failure.

## Limits

- zsh scripts only get a syntax check (`zsh -n`): there is no zsh linter, and shellcheck doesn't support zsh.
  Write new scripts in sh or bash so shellcheck covers them.
- Scripts written inline in Nix with `writeShellApplication` are shellchecked when their package builds, not here.
- Coverage isn't measured. Shell coverage tools (kcov, bashcov) don't work well on macOS.
- ruff runs with its default rules (`--isolated`), so a personal ruff config doesn't change the result.
