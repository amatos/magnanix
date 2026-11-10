# Aspect:    den.aspects.neovim (included by base)
# Platforms: home-manager
# Purpose:   Neovim with LazyVim (via lazyvim-nix), as $EDITOR; vi, vim and
#            vimdiff run it too.
#
# Notes:
# - Everything comes from Nix: plugins, Treesitter parsers, language servers
#   and formatters. Mason is disabled and lazy.nvim never clones from GitHub,
#   so Neovim starts offline and works on NixOS.
# - Nix owns the config, so :LazyExtras changes don't persist; enable extras in
#   programs.lazyvim.extras here.
# - Only EDITOR is set. Where Zed is installed, VISUAL points at Zed, and most
#   programs (git, crontab) prefer VISUAL.
# - Theme: Dracula PRO (dark/alucard, following the terminal's background) for
#   users with magnanix.draculaPro and a checkout; free Dracula otherwise.
{ inputs, ... }:
{
  # Home Manager module that builds LazyVim declaratively: plugins and
  # Treesitter parsers come from Nix rather than being downloaded by lazy.nvim
  # at startup, and Mason is disabled, so it works offline and on NixOS.
  flake-file.inputs.lazyvim-nix = {
    url = "github:pfassina/lazyvim-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.neovim = {
    homeManager =
      { config, pkgs, ... }:
      let
        # Users who own Dracula PRO opt in with `magnanix.draculaPro` (see
        # modules/den/dracula-pro.nix); everyone else gets the free Dracula theme.
        # The PRO Vim theme is loaded straight from the checkout at runtime, so
        # its licensed files never enter the Nix store. Neovim deliberately
        # doesn't add itself to `magnanix.draculaPro.usedBy`: it runs on headless
        # hosts too, where the clone should not be attempted. It uses the
        # checkout wherever one exists (cloned for Ghostty, or by hand).
        draculaPro = config.magnanix.draculaPro;
        draculaProVim = if draculaPro.enable then "${draculaPro.dir}/themes/vim" else null;
      in
      {
        imports = [ inputs.lazyvim-nix.homeManagerModules.default ];

        programs.lazyvim = {
          enable = true;

          # Prefer the plugin and parser builds in nixpkgs, which cache.nixos.org
          # already has, over building LazyVim's exact pinned versions from source.
          pluginSource = "nixpkgs";

          # LazyVim turns on its blink.cmp completion extra by itself, but
          # lazyvim-nix only builds the plugins of extras declared here; without
          # this, lazy.nvim clones blink.cmp and friendly-snippets at startup.
          extras.coding.blink.enable = true;

          # Languages this repo is written in. Each extra adds its plugins and
          # Treesitter parsers; installDependencies adds its LSP servers and tools.
          extras.lang = {
            nix.enable = true; # its tools come from extraPackages below
            json = {
              enable = true;
              installDependencies = true;
            };
            markdown = {
              enable = true;
              installDependencies = true;
            };
            toml = {
              enable = true;
              installDependencies = true;
            };
            yaml.enable = true;
          };

          # Tools LazyVim starts that lazyvim-nix has no package mapping for, so
          # installDependencies can't add them. With Mason disabled, a missing
          # language server is an error each time a file of its type opens.
          # These go on Neovim's own PATH, so nil and nixfmt (which nix-tools
          # also installs) don't depend on that aspect.
          extraPackages = with pkgs; [
            # LazyVim core: Lua (its own config language) and shell scripts
            lua-language-server
            stylua
            shfmt
            # lang.nix
            nil
            nixfmt
            statix
            # lang.markdown
            marksman
            # lang.yaml
            yaml-language-server
          ];

          # Plugins LazyVim loads that lazyvim-nix doesn't provide under the name
          # lazy.nvim looks for; without these specs lazy.nvim would clone them
          # from GitHub at startup.
          plugins.nix-provided = ''
            return {
              -- blink.cmp's snippet collection, which lazyvim-nix doesn't package.
              { "rafamadriz/friendly-snippets", dir = ${builtins.toJSON pkgs.vimPlugins.friendly-snippets} },
              -- LazyVim's alternative theme, unused here (see colorscheme.lua).
              -- lazyvim-nix links it under its repo name (`nvim`), not `catppuccin`.
              { "catppuccin/nvim", name = "catppuccin", enabled = false },
            }
          '';

          # Follows the terminal's light/dark appearance, like Ghostty and Zed:
          # Neovim sets 'background' from the terminal's colors at startup.
          plugins.colorscheme = ''
            local dracula_pro = ${if draculaProVim == null then "nil" else builtins.toJSON draculaProVim}
            local have_pro = dracula_pro ~= nil and vim.uv.fs_stat(dracula_pro) ~= nil

            local function apply()
              if have_pro then
                vim.cmd.colorscheme(vim.o.background == "light" and "dracula-pro-alucard" or "dracula-pro")
              else
                vim.cmd.colorscheme("dracula")
              end
            end

            -- The terminal's answer usually arrives after LazyVim has applied the
            -- colorscheme, and changing 'background' makes Neovim reload the
            -- current one, so pick the variant again whenever it changes.
            vim.api.nvim_create_autocmd("OptionSet", {
              pattern = "background",
              callback = apply,
            })

            return {
              have_pro and { dir = dracula_pro, name = "dracula-pro", lazy = false, priority = 1000 }
                or { dir = ${builtins.toJSON pkgs.vimPlugins.dracula-nvim}, name = "dracula.nvim", lazy = false, priority = 1000 },
              { "LazyVim/LazyVim", opts = { colorscheme = apply } },
            }
          '';
        };

        # LazyVim's starter init.lua clones lazy.nvim from GitHub on first launch
        # unless it finds it here. Link the Nix build instead, so Neovim starts
        # without network access. `recursive` makes it a real directory of
        # linked files: lazy.nvim only counts directories under its root as
        # installed, and would try to re-clone over a symlinked one. It treats
        # the copy it runs from as its own, so `:Lazy clean` leaves it alone.
        xdg.dataFile."${config.programs.lazyvim.appName}/lazy/lazy.nvim" = {
          source = pkgs.vimPlugins.lazy-nvim;
          recursive = true;
        };

        programs.neovim = {
          viAlias = true;
          vimAlias = true;
          vimdiffAlias = true;
        };

        # Only EDITOR: hosts that run Zed set VISUAL to it (modules/packages/zed/zed.nix).
        # Elsewhere VISUAL stays unset and programs fall back to EDITOR. This is why
        # programs.neovim.defaultEditor is off: it sets VISUAL too, and two
        # different VISUAL values would fail evaluation.
        home.sessionVariables.EDITOR = "nvim";
      };
  };
}
