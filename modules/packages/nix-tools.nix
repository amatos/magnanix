# Basic devShell for working on this flake.
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
        alejandra
        nixfmt
        nh
        nil
        nixd

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
