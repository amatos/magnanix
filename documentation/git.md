# Git

The `git` feature (`modules/packages/git.nix`, included by `base`) configures git through Home Manager for every
user, taking `user.name` and `user.email` from the user's [metadata](architecture.md#user-metadata). Besides git itself it
installs:

| Tool                                                  | Use                                                                                                   |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| [git-lfs](https://git-lfs.com)                        | large files stored as pointers                                                                        |
| [delta](https://github.com/dandavison/delta)          | pager for `diff`, `log`, `show`, `blame` and `add -p`, with line numbers (`n`/`N` jump between files) |
| [difftastic](https://difftastic.wilfred.me.uk)        | syntax-aware diffs on demand: `git difftool`                                                          |
| [mergiraf](https://mergiraf.org)                      | syntax-aware merge driver; falls back to line-based merging when unsure                               |
| [lazygit](https://github.com/jesseduffield/lazygit)   | terminal UI for staging, rebasing and history, using delta for diffs                                  |
| [git-absorb](https://github.com/tummychow/git-absorb) | `git absorb` turns staged changes into `fixup!` commits for the right earlier commits                 |
| [git-extras](https://github.com/tj/git-extras)        | extra subcommands (`git summary`, `git undo`, ...); the zsh plugin adds completions                   |

Defaults worth knowing: new repositories start on `main`; `git push` sets the upstream on first push; `fetch`
prunes deleted branches and tags; `rebase` auto-stashes, applies `fixup!` commits and moves stacked branches
(`updateRefs`); `rerere` remembers conflict resolutions; diffs use the histogram algorithm. `merge.conflictStyle`
is `diff3` because mergiraf requires it. Home Manager won't enable delta's and difftastic's git integrations
together, so difftastic is wired up by hand as `diff.tool`. `pull` is left at git's default.

## Commit signing

Signing is off by default, since a GPG key on a YubiKey isn't available on every host. `den.aspects.git.signing`
signs commits and tags with the user's `meta.gpgKey`. Include it for a user on the hosts where that key is usable,
through the host's `provides.<user>`:

```nix
den.aspects.<host>.provides.<user>.includes = [ den.aspects.git.signing ];
```

## Tower

`den.aspects.macos.tower` (`modules/packages/tower.nix`, included by magnus) installs [Tower](https://www.git-tower.com)
as a Homebrew cask, since it isn't in nixpkgs. The cask updates itself, and the license comes from git-tower.com.

It also gives Tower Dracula themes, written to `~/Library/Application Support/com.fournova.Tower3/Themes`:

- **Dracula**, the free theme, linked from the Nix store. Tower uses it in dark mode for users without
  `magnanix.draculaPro`.
- **Dracula PRO** and its variants (Alucard, Blade, Buffy, Lincoln, Morbius, Nosferatu, Van Helsing), for users
  with `magnanix.draculaPro`. Dracula PRO is licensed, so its colors never enter this repo or the Nix store:
  each switch reads them from the checkout's `design/palette.md` and writes the theme files, rewriting a file
  only when it changes. Tower uses Dracula PRO in dark mode and Dracula PRO Alucard in light mode. Tower also adds
  itself to `draculaPro.usedBy`, so the checkout is cloned on hosts that run it.

Every theme shares one layout (`mkTheme`), which maps Dracula's color roles onto Tower's fields the way the
[Dracula spec](https://draculatheme.com/spec) does, in JetBrains Mono Nerd Font Mono at 12pt. Change themes there
rather than in Tower's theme editor: the Dracula file is read-only, and the next switch overwrites the PRO files.

> [!NOTE]
> Quit Tower before switching. A running Tower may overwrite the theme settings (`GTUserDefaultsDarkTheme` and
> `GTUserDefaultsLightTheme`) with the values it already has in memory. Before the Dracula PRO checkout exists,
> the PRO themes are skipped with a warning and Tower shows its default theme until the next switch.
