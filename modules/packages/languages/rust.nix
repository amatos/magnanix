# Rust toolchain and development tools.
{
  den.aspects.rust = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          # ── Toolchain ──────────────────────────────────────────────────────────
          rustc # compiler
          cargo # build tool and package manager
          clippy # linter
          rustfmt # code formatter
          rust-analyzer # language server (LSP)

          # ── Cargo extensions ───────────────────────────────────────────────────
          cargo-edit # cargo upgrade — update dependency versions in Cargo.toml
          cargo-nextest # faster test runner
          cargo-audit # check dependencies for known vulnerabilities
          bacon # background checker that reruns on file changes
        ];
      };
  };
}
