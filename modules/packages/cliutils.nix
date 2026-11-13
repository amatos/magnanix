# Aspect:    den.aspects.cliutils (included by base)
# Platforms: home-manager
# Purpose:   Modern replacements and companions for the classic Unix tools
#            (ripgrep, fd, fzf, bat, eza, jq, bottom, btop, htop, ...).
#
# Notes:
# - Aliases ls/ll/la/lt -> eza, cat -> bat, top -> btm and df -> duf, in bash,
#   zsh and fish only. Nushell keeps its built-in, structured `ls`.
# - To get the original tool, bypass the alias: `command ls` or `\ls`.
{
  den.aspects.cliutils = {
    homeManager =
      { pkgs, ... }:
      let
        modernAliases = {
          ls = "eza --icons auto";
          ll = "eza -l --git --icons auto";
          la = "eza -la --git --icons auto";
          lt = "eza --tree --level=2 --icons auto";
          cat = "bat --plain --paging=never";
          top = "btm";
          df = "duf";
        };
      in
      {
        programs = {
          bash.shellAliases = modernAliases;
          fish.shellAliases = modernAliases;
          zsh.shellAliases = modernAliases;
        };

        home.packages = with pkgs; [
          # ── Search and navigation ──────────────────────────────────────────────
          ripgrep # rg — recursive grep that respects .gitignore
          fd # friendlier find
          fzf # fuzzy finder (used by fzf-tab and the shell functions)

          # ── Viewing files ──────────────────────────────────────────────────────
          bat # cat with syntax highlighting (used by fzf-tab previews)
          eza # ls with git status and icons (used by fzf-tab previews)
          glow # render Markdown in the terminal

          # ── Structured data and text ───────────────────────────────────────────
          jq # JSON processor (used by the shell functions)
          yq-go # jq for YAML, TOML and XML
          sd # simpler sed for find-and-replace

          # ── System inspection ──────────────────────────────────────────────────
          bottom # btm — top with graphs
          btop # resource monitor with a full-screen TUI
          htop # the classic interactive process viewer
          procs # ps with readable, searchable output
          dust # du as a sorted tree
          duf # df as a readable table

          # ── Network ────────────────────────────────────────────────────────────
          xh # curl-like HTTP client with friendlier syntax
          doggo # dig with readable output

          # ── Development ────────────────────────────────────────────────────────
          hyperfine # command-line benchmarking
          tokei # count lines of code by language
          just # command runner
        ];
      };
  };
}
