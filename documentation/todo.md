# TODO

- When `alberth` declares a Home Manager secret, add each machine's user key to the `alberth.yaml` rule in
  `.sops.yaml`: `alberth_muninn` already exists; `fortuna` needs an `alberth_fortuna` key generated first.
- Wire up `github_access_token` from `secrets/common.yaml`, which nothing declares yet: give Nix a GitHub
  `access-tokens` entry so fetches avoid GitHub's rate limit for anonymous requests. Render
  `access-tokens = github.com=<token>` with a sops template and `!include` its path (`!include` skips a missing
  file). On NixOS, use `nix.extraOptions`. On macOS, `determinateNix.customSettings` only writes `key = value`
  lines, but `environment.etc."nix/nix.custom.conf".text` is `types.lines`, so append the line with `lib.mkAfter`.
  The `nix` client fetches flake inputs itself, so the template must be readable by `alberth`, not only root.
- Remove the `doCheck = false` override on `cargo-llvm-cov` in `modules/packages/languages/rust.nix` (see
  [Rust](languages.md#rust)) once nixpkgs fixes its tests. After updating inputs, check with
  `nix build --no-link --inputs-from . nixpkgs#cargo-llvm-cov` on any host: it builds the unmodified package from
  the pinned nixpkgs, tests included, so success means the override can go. The tests fail on both macOS and
  Linux, so one host is enough.
