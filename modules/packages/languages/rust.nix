# Rust toolchain and development tools.
{
  den.aspects.rust = {
    homeManager =
      { pkgs, ... }:
      {
        # Binaries installed with `cargo install` go here.
        home.sessionPath = [ "$HOME/.cargo/bin" ];

        home.packages = with pkgs; [
          # ── Toolchain ──────────────────────────────────────────────────────────
          # Toolchain manager. Honors a project's rust-toolchain.toml and provides
          # cargo, rustc, clippy, rustfmt and rust-analyzer as proxies, so those
          # aren't installed from nixpkgs (they would collide).
          rustup

          # ── Cargo extensions ───────────────────────────────────────────────────
          cargo-edit # cargo upgrade — update dependency versions in Cargo.toml
          cargo-nextest # faster test runner
          # Source-based code coverage (needs llvm-tools-preview). Its integration
          # tests build coverage-instrumented binaries with nixpkgs' rustc, and
          # those segfault (seen on aarch64-darwin and x86_64-linux), so skip them.
          # The tool itself builds fine and uses rustup's toolchain at runtime.
          # Drop this once nixpkgs fixes the tests (see the README's TODO).
          (cargo-llvm-cov.overrideAttrs { doCheck = false; })
          cargo-audit # check dependencies for known vulnerabilities
          cargo-shear # find unused dependencies
          cargo-expand # show macro-expanded code
          bacon # background checker that reruns on file changes

          # ── Related ────────────────────────────────────────────────────────────
          taplo # TOML formatter and language server (Cargo.toml)
        ];
      };
  };
}
