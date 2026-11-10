# Neovim

`den.aspects.neovim` (`modules/packages/neovim.nix`, included by `base`) installs Neovim with
[LazyVim](https://www.lazyvim.org) on every host, through the [lazyvim-nix](https://github.com/pfassina/lazyvim-nix)
Home Manager module, and sets `EDITOR=nvim`. `vi`, `vim` and `vimdiff` run Neovim too.

- **From Nix, not the network:** plugins, Treesitter parsers, language servers and formatters are all built by
  Nix, and Mason is disabled, so Neovim starts offline and works on NixOS. A few specs in the aspect fill gaps in
  lazyvim-nix that would otherwise make lazy.nvim clone plugins from GitHub at startup (lazy.nvim itself,
  `friendly-snippets`, `catppuccin`). Nix owns the config, so changes made through `:LazyExtras` don't persist; enable
  extras with `programs.lazyvim.extras` instead. LazyVim's version comes from the `lazyvim-nix` input in `flake.lock`.
- **Languages:** the `lang.nix`, `json`, `markdown`, `toml` and `yaml` extras. Tools that lazyvim-nix doesn't map to
  a package (such as `yaml-language-server`, `marksman` and `lua-language-server`) are listed in `extraPackages`;
  with Mason disabled, a missing language server is an error whenever a file of its type opens.
- **`EDITOR` and `VISUAL`:** the aspect sets only `EDITOR`. Hosts with Zed set `VISUAL=zed --wait` on macOS
  or `VISUAL=zeditor --wait` on Linux (from `zed-editor-fhs`; `modules/packages/zed/zed.nix`), and most programs (git, crontab, ...) prefer `VISUAL`, so on those hosts they
  open Zed. Elsewhere `VISUAL` is unset and they use Neovim. Home Manager's `programs.neovim.defaultEditor` stays off
  because it would also set `VISUAL`, and the two definitions would fail evaluation.
- **Theme:** users with `magnanix.draculaPro` get Dracula PRO, loaded at runtime from the checkout (never copied
  into the store): `dracula-pro` on a dark terminal and `dracula-pro-alucard` on a light one, following the
  `background` Neovim detects from the terminal at startup. Everyone else, and hosts without the checkout, get the
  free Dracula theme. Neovim doesn't add itself to `draculaPro.usedBy`, so it never triggers the clone, which keeps
  headless hosts from trying. Clone the checkout there by hand to get Dracula PRO in Neovim.
