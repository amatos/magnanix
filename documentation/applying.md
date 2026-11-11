# Applying and updating

## Applying the configuration

The configuration expects its live checkout at `~/Developer/magnanix` (the `magnanix.repoDir` default in
`modules/den/repo-dir.nix`): out-of-store symlinks such as Zed's `settings.json` point into it, and the
`deploy-magnanix` script pulls there. Clone it there, or set `magnanix.repoDir` in a `homeManager` module for
that user or host. If the checkout isn't there, activation warns and skips Zed's `settings.json` instead of
creating a stray directory at `magnanix.repoDir`.

Enter the dev shell and run the `apply-configuration` script. It picks the right command for the machine and
uses the machine's host name:

```sh
nix develop --command apply-configuration
```

- On macOS it runs `sudo darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"`.
- On NixOS it runs `sudo nixos-rebuild switch --flake ".#$(hostname)"`.

Each host also has an `nh` wrapper, for example `nix run .#magnus -- switch`.

`alberth`'s `deploy-magnanix` script (`modules/users/alberth/deploy-magnanix.nix`, installed as
`~/.local/bin/deploy-magnanix`) deploys the checkout at
`magnanix.repoDir`: it checks out `main` there, runs `git pull --ff-only`, then the current host's `nh` wrapper
with `switch`, and checks the original branch back out afterwards (even if the deploy fails). It refuses to run
from another branch with uncommitted changes, and stops with an error if `magnanix.repoDir` doesn't exist or isn't
a git checkout. Because it is a script on `PATH` rather than a shell alias, it also runs over SSH, for example
`ssh <host> deploy-magnanix`. Deploy after CI passes on `main`.

To deploy the whole fleet at once, run `update-all-magnanix` (`modules/users/alberth/scripts/update-all-magnanix`).
It runs `deploy-magnanix` on fortuna, magnus and muninn in parallel (the test VMs are left out; pass host names
to deploy only those), over SSH for the other hosts and directly on the machine it runs on, since macOS sudo can't
prompt over a non-interactive SSH session. Output is prefixed with each host's name. At the end it prints a
summary, and for each failed host the end of its log; it exits non-zero if any host failed. Remote hosts must
accept your SSH key without a prompt (it uses `BatchMode`).

To build without activating:

```sh
darwin-rebuild build --flake .#magnus      # macOS
nixos-rebuild build --flake .#muninn       # NixOS
```

## Updating inputs

The `Update flake inputs` workflow (`.github/workflows/update-flake-lock.yml`) runs every Saturday at 06:00 UTC,
or on demand from the Actions tab. It runs `nix flake update` and `nix run .#write-flake`, then opens or refreshes
a pull request from the `update-flake-lock` branch listing the inputs that changed. Before merging it, test it
on a Mac with `darwintron-vm test update-flake-lock`.

Pull requests opened with the default `GITHUB_TOKEN` don't trigger other workflows. For CI to run on the update
PR, add a fine-grained personal access token limited to this repository, with read and write access to Contents
and Pull requests, as the `GH_TOKEN_FOR_UPDATES` repository secret. Without it, close and reopen the PR to start
CI.

## Direnv

`.envrc` contains `use flake`, so with [direnv](https://direnv.net) the dev shell loads automatically in this
directory (run `direnv allow` once). The `direnv` feature (`modules/packages/direnv.nix`, included by `alberth`)
installs direnv through Home Manager with nix-direnv and shell integration enabled.

`.envrc` also sets `NIX_SENTRY_ENDPOINT=""` before `use flake`. Determinate Nix starts a Crashpad-based Sentry
crash reporter, which aborts on macOS inside sandboxes that deny Mach service registration (for example agent
terminals), with `bootstrap_check_in ... Permission denied (1100)`. An empty endpoint disables the reporter, so
`nix` runs normally. The side effect is that Determinate no longer receives Nix crash reports from this directory.
Outside direnv, prefix the command instead: `NIX_SENTRY_ENDPOINT= nix ...`.
