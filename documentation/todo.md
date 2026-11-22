# TODO

- When `alberth` declares a Home Manager secret, add each machine's user key to the `alberth.yaml` rule in
  `.sops.yaml`: `alberth_muninn` already exists; `fortuna` needs an `alberth_fortuna` key generated first.
- Remove the unused `github_access_token` from `secrets/common.yaml` (and revoke that token on GitHub) once
  nothing needs it. Hosts now use `github_secrets_repo_access_token` through `den.aspects.nix-access-tokens`.
- Remove the `doCheck = false` override on `cargo-llvm-cov` in `modules/packages/languages/rust.nix` (see
  [Rust](languages.md#rust)) once nixpkgs fixes its tests. After updating inputs, check with
  `nix build --no-link --inputs-from . nixpkgs#cargo-llvm-cov` on any host: it builds the unmodified package from
  the pinned nixpkgs, tests included, so success means the override can go. The tests fail on both macOS and
  Linux, so one host is enough.
