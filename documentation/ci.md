# Continuous Integration

magnanix uses [GitHub Actions](https://docs.github.com/en/actions) to check every change cheaply, build every host
when it matters, and cache the results in muninn's Attic binary cache server.

## The build.yml workflow

[`.github/workflows/build.yml`](../.github/workflows/build.yml) has two tiers.

**Evaluate** runs on every pull request and every push to `main`. It needs no secrets and builds nothing:

- `nixfmt --check` on every tracked `.nix` file
- `checks.x86_64-linux.check-flake-file` (`flake.nix` matches what `nix run .#write-flake` generates)
- evaluates every host's system derivation: NixOS hosts on `ubuntu-latest`, nix-darwin hosts on `macos-26`. The
  host lists come from the flake, so a new host is covered without editing the workflow.

The nix-darwin hosts are evaluated on macOS because `magnus` (like `fortuna`) imports from a derivation, the
zen-browser presets, and that derivation has to be built on the host's own system.

**Build** runs after evaluation passes, but only for:

- pushes to `main` (every merged PR), so the cache is warm before you deploy
- the weekly `update-flake-lock` PR
- a PR labelled `ci:build`; adding the label starts a build, and later pushes to the PR keep building
- a manual run from the Actions tab (`workflow_dispatch`)

It builds and pushes to the cache:

- **aarch64-darwin:** `magnus` and `darwintron`
- **x86_64-linux:** `muninn`, `fortuna` and `nixostron-x86_64`
- **aarch64-linux:** `nixostron-aarch64`

Each build job sets up the cache with the shared [`attic-cache`](../.github/actions/attic-cache/action.yml) composite
action:

1. Joins the Tailscale network via **Workload Identity Federation** (ephemeral GitHub OIDC token)
2. Authenticates to the Attic cache with a scoped CI token
3. Configures Nix to use the cache as a substituter

then builds its hosts and runs `attic push` on the results, even when a later build fails.

Changes that only touch Markdown, `documentation/` or `LICENSE` don't run the workflow. PRs from forks get no
secrets, so only the evaluate tier works for them.

## Runners

All runners are GitHub-hosted (no self-hosted infrastructure):

| Platform       | Runner                | Used for                         |
|---|---|---|
| aarch64-darwin | `macos-26`            | evaluating and building darwin hosts |
| x86_64-linux   | `ubuntu-latest`       | evaluate tier checks; building x86_64 NixOS hosts |
| aarch64-linux  | `ubuntu-24.04-arm`    | building `nixostron-aarch64` |

Hosted runners are free for public repositories. On a private one, macOS minutes count 10x against the free
allowance, which is why ordinary PRs only evaluate.

## Cache security

- **Ephemeral tokens:** GitHub's OIDC token is valid only ~5 minutes per workflow run and cannot be reused.
- **Scoped network access:** Tailscale ACL restricts `tag:ci` to `muninn.ts.matos.cc:8080` only.
- **Scoped Attic token:** CI token can only pull and push to the `magnanix` cache, with 1-year TTL.

## Setup & troubleshooting

See [TAILSCALE_SETUP.md](TAILSCALE_SETUP.md) for detailed instructions on enabling GitHub Actions to access the cache. The setup requires:
- A Tailscale OIDC credential (subject wildcard: `repo:amatos:367718/magnanix@1435869087:*`)
- Three GitHub Action secrets: `TS_OAUTH_CLIENT_ID`, `TS_AUDIENCE`, `ATTIC_TOKEN`
- An ACL rule allowing `tag:ci → muninn:8080` (kept in [`documentation/tailscale-policy/acl.hujson`](tailscale-policy/acl.hujson))

Don't add a top-level directory named `tailscale/`. On macOS runners, `tailscale/github-action` builds Tailscale from
source by cloning it into `./tailscale` inside the checkout, and the darwin job fails with "destination path
'tailscale' already exists" if that path is taken.

On macOS, the `attic-cache` action also resets the runner's DNS right after joining the tailnet. There, Tailscale's
action points system DNS at MagicDNS (`100.100.100.100`), which fails to resolve public names on hosted runners
([tailscale/github-action#315](https://github.com/tailscale/github-action/issues/315)). That's safe because
`muninn.ts.matos.cc` is in public DNS, so CI doesn't need MagicDNS to find it.
