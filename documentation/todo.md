# TODO

- Revoke the old `github_access_token` on GitHub. Nothing uses it: it wasn't migrated to nix-secrets, and its
  encrypted copy goes with `secrets/common.yaml` in the sops-nix cleanup.
- Finish the nix-secrets migration: soak, then remove sops-nix ([NIX_SECRETS_PLAN.md](NIX_SECRETS_PLAN.md),
  Phases 5 and 6).
- Remove the `doCheck = false` override on `cargo-llvm-cov` in `modules/packages/languages/rust.nix` (see
  [Rust](languages.md#rust)) once nixpkgs fixes its tests. After updating inputs, check with
  `nix build --no-link --inputs-from . nixpkgs#cargo-llvm-cov` on any host: it builds the unmodified package from
  the pinned nixpkgs, tests included, so success means the override can go. The tests fail on both macOS and
  Linux, so one host is enough.
