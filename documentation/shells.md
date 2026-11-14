# Shells

Shell configuration lives in `modules/packages/shells/`, one aspect per shell plus shared pieces. The `base` aspect
includes `shell.zsh`, `shell.fish`, `shell.bash` and `shell.nushell`, so every host and user gets all four:

```nix
den.aspects.base.includes = [
  den.aspects.shell.bash
  den.aspects.shell.fish
  den.aspects.shell.nushell
  den.aspects.shell.zsh
];
```

| Aspect                 | File                        | What it does                                                                                |
| ---------------------- | --------------------------- | ------------------------------------------------------------------------------------------- |
| `shell.zsh`            | `zsh.nix`                   | Home Manager `programs.zsh`                                                                 |
| `shell.fish`           | `fish.nix`                  | Home Manager `programs.fish`, plus system-level fish on NixOS and macOS                     |
| `shell.bash`           | `bash.nix`                  | Home Manager `programs.bash`                                                                |
| `shell.nushell`        | `nushell.nix`               | Home Manager `programs.nushell`, without the shared aliases or functions                    |
| `shell.starship`       | `starship.nix`              | Home Manager `programs.starship` with a default `starship.toml`; the prompt for every shell |
| `shell.shellAliases`   | `shell-aliases.nix`         | aliases shared by the shells, and per-OS `environment.shellAliases`                         |
| `shell.posixFunctions` | `shell-functions-posix.nix` | shared functions for zsh and bash                                                           |
| `shell.fishFunctions`  | `shell-functions-fish.nix`  | the same functions, written for fish                                                        |

Each POSIX and fish shell aspect includes the aliases, functions and `shell.starship` aspects it needs.

**Login shell.** `alberth`'s login shell is Nix's zsh on every host, set in `modules/users/alberth/alberth.nix`
(`shell.zsh` also enables `programs.zsh` at system level, which the setting requires). `ephemeral` does the same in
its own file:

- **NixOS:** `users.users.alberth.shell = pkgs.zsh`. This overrides the fish default that `shell.fish` sets with
  `users.defaultUserShell`.
- **macOS:** nix-darwin only applies `users.users.<name>.shell` to users in `users.knownUsers`, and listing
  `alberth` there would make nix-darwin manage (and possibly delete) the account. So the config adds Nix's zsh
  to `/etc/shells` (`environment.shells`) and sets the shell on the existing account with `dscl` in a
  `postActivation` script. It runs after every activation and only changes the shell if it differs. Open a new
  terminal after the first switch for it to take effect.
  Check it with `dscl . -read /Users/alberth UserShell`; it should be `/run/current-system/sw/bin/zsh`.

- **zsh:** config lives in `$XDG_CONFIG_HOME/zsh`. oh-my-zsh is enabled with its theme turned off, because
  Starship draws the prompt. The history file is
  `~/.local/share/zsh/history`, effectively unlimited and shared between sessions. Plugins load in this order:
  `fzf-tab` (must be first), `zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-history-substring-search`,
  `you-should-use`. On Linux the `fzf-tab` native module is stripped so it falls back to pure zsh. A glibc
  mismatch stops the prebuilt module loading on non-NixOS hosts, and the fallback avoids that. `envExtra` sources
  the Nix daemon profile, so `nix` is on `PATH` when zsh is the login shell on non-NixOS Linux.
- **fish:** Home Manager enables fish integration, turns off the greeting, and installs the `autopair` and `bass`
  plugins. Fish is also enabled at system level on NixOS (where it becomes the default user shell) and on macOS.
  OS-specific aliases and functions live next to that (xclip clipboard aliases and PulseAudio and DNS resets on
  NixOS; `pbcopy` aliases and `tail-exit-node-fix` on macOS). Only one-line commands are aliases; multi-line
  helpers are real fish functions. On NixOS they're in `programs.fish.shellFunctions` (installed as
  `/etc/fish/functions/<name>.fish`); nix-darwin has no such option, so on macOS they're `function … end` blocks
  in `programs.fish.interactiveShellInit`.
- **Starship prompt:** the shell indicator is on, so each prompt shows which shell you're in: 🐚 bash, 🦓 zsh,
  🐟 fish, 🪟 PowerShell, and ❓ for anything else. The hostname is trimmed at the first `.` (`host.example.com`
  shows as `host`).
- **Nushell:** `programs.nushell` writes `config.nu` and `env.nu` (in `~/Library/Application Support/nushell` on
  macOS), so the atuin, direnv, starship, yazi and zoxide integrations load in it too. `loadSessionVariables` loads
  the Home Manager session variables (such as `EDITOR`) when Nushell starts without them, for example as the
  shell a terminal opens directly.
- **1Password CLI:** zsh and fish both load `$XDG_CONFIG_HOME/op/plugins.sh` if it exists (fish through `bass`).
  The `_1password` aspect adds `op` completions to bash, zsh and fish, so they only load on hosts that include it.
- **Aliases and functions:** the common aliases (`rm`/`mv`/`cp` with `-i`, the `ssh*` variants, `git-log`,
  `git-author`) apply to zsh and fish. `cli.utils` adds `ls`, `ll`, `la` and `lt` as `eza --icons auto` aliases
  (plus `cat` → `bat`, `top` → `btm`, `df` → `duf`; `btop` is installed but not aliased) to bash, zsh and fish;
  Nushell keeps its built-in structured `ls`. The functions cover GPG and YubiKey resets, Docker cleanup, Tailscale
  and DNS fixes, network info, and a zoxide and fzf directory jumper (`zox`). They are written once for POSIX
  shells and once for fish, so keep the two files in step when adding or changing one. In `shell-functions-posix.nix`
  each entry becomes a shell function; in `shell-functions-fish.nix` it becomes a fish function.
- **Pager:** `alberth`'s Home Manager config (`modules/users/alberth/alberth.nix`) sets `PAGER` to
  `bat --color=always` and `MANPAGER` to `sh -c 'col -bx | bat -l man -p'`, both using bat's full store path.
  `col -bx` strips man's overstrike bold and underline so bat can highlight the page as man syntax. bat itself
  ignores `PAGER=bat` and falls back to `less`. Git still pages through delta (see [Git](git.md)).
