# Aspect:    den.aspects.python
# Platforms: home-manager, nixos
# Purpose:   python3 for ad-hoc scripts, uv (projects, venvs, Python versions),
#            Ruff (lint + format), basedpyright and ty.
#
# Notes:
# - Per-project Python versions are uv's job, not Nix's.
# - NixOS: nix-ld is enabled because uv's standalone Python builds expect a
#   generic /lib64 dynamic loader that NixOS doesn't have.
{
  den.aspects.python = {
    # uv installs standalone Python builds, which are dynamically linked against a
    # generic /lib64 loader that NixOS doesn't provide. nix-ld supplies one.
    nixos = {
      programs.nix-ld.enable = true;
    };

    homeManager =
      { pkgs, ... }:
      {
        # Project, dependency, virtualenv, build/publish and Python version manager.
        # Global settings go in `settings` (~/.config/uv/uv.toml).
        programs.uv.enable = true;

        # Linter and formatter. Global defaults go in `settings`
        # (~/.config/ruff/ruff.toml); a project's own config takes precedence.
        programs.ruff.enable = true;

        home.packages = with pkgs; [
          python3 # runtime for ad-hoc scripts; uv manages per-project versions
          basedpyright # language server (LSP) and type checker
          ty # Astral's type checker and language server (LSP)
        ];
      };
  };
}
