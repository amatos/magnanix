# Aspect:    den.aspects.nix-tools (included by base)
# Platforms: home-manager
# Purpose:   Tools for working with Nix: search (nix-search-tv, manix, comma +
#            nix-index), rebuild helpers (nh, nom, nvd), formatters (nixfmt,
#            alejandra), language servers (nil, nixd) and inspection/diagnostic
#            tools. nixfmt is the one this repo is formatted with.
{
  den.aspects.nix-tools = {
    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        # ── Tier 1 — high daily value ──────────────────────────────────────────
        nix-search-tv # fzf-based search across nixpkgs, HM/NixOS/darwin options
        comma # run any program without installing (, ripgrep)
        nix-index # file→package database for comma
        nvd # diff package versions between NixOS generations
        nix-output-monitor # pretty build output (nom) — dependency tree, progress
        manix # fast Nix documentation/options search
        alejandra # opinionated Nix code formatter
        nixfmt # official Nix code formatter (RFC 166 style)
        nh # friendlier wrapper for nixos/darwin/home-manager rebuilds and GC
        nil # Nix language server (LSP)
        nixd # Nix language server with option and package evaluation

        # ── Tier 2 — better workflow ───────────────────────────────────────────
        nix-inspect # TUI for exploring Nix config (ranger-like, fuzzy search)
        nurl # generate Nix fetcher expressions from repo URLs
        nix-init # generate full package expressions from URLs

        # ── Tier 3 — nice to have ─────────────────────────────────────────────
        nix-diff # debug why derivations differ
        nix-du # visualize store space by GC root
        nix-melt # browse flake.lock visually
        nix-health # one-time Nix install health check
        flake-checker # CI health check for stale flake inputs
      ];
    };
  };
}
