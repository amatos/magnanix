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
