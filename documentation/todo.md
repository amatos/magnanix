# TODO

- `fortuna`: add an `alberth_fortuna` key to the `alberth.yaml` rule once `alberth` declares a Home Manager secret.
  Its second NVMe drive (the Samsung 970 EVO Plus) is reserved for Windows 11; keep NixOS off it.
- Replace the example content in `secrets/common.yaml`, `secrets/hosts/magnus.yaml`
  and `secrets/users/alberth.yaml` with real secrets and declare them as
  `sops.secrets.<name>`.
- `muninn`: add `alberth_muninn` to the `alberth.yaml` rule once `alberth` declares a Home Manager secret.
- Fill in the empty `os` block in `base`, or remove it. (`darwin` is kept, empty, for macOS-only baseline options.)
- Test the nixostron-vm rollback on `magnus` with a branch that changes nixostron's configuration: `test main`
  builds the baseline's own system, so it skips the rollback.
- Decide whether to set nix-darwin's `power.restartAfterFreeze` and a Nix `cores` limit again; the old
  `nix-darwin-settings.nix` that set them was never wired in and has been removed.
- Remove the `doCheck = false` override on `cargo-llvm-cov` in `modules/packages/languages/rust.nix` (see
  [Rust](languages.md#rust)) once nixpkgs fixes its tests. After updating inputs, check with
  `nix build --no-link --inputs-from . nixpkgs#cargo-llvm-cov` on any host: it builds the unmodified package from
  the pinned nixpkgs, tests included, so success means the override can go. The tests fail on both macOS and
  Linux, so one host is enough.
- `fortuna`: try [game streaming](game-streaming.md) for real. It evaluates, but no session has run yet; the parts most
  likely to need fixing are libinput under `LIBSEAT_BACKEND=noop` and Sunshine's wlr capture with VAAPI. Consider a
  cut-down NixOS VM test (Sway, Sunshine, no Steam) once it works.
