{ den, ... }: {
  den.aspects.shell.zsh = {
    includes = [
      den.aspects.shell.shellAliases
      den.aspects.shell.posixFunctions
      den.aspects.shell.starship
    ];
    # System-level zsh: puts Nix's zsh in /etc/shells (so it can be a login shell)
    # and gives it the basic Nix PATH setup. Required for users.users.<name>.shell = pkgs.zsh.
    os.programs.zsh.enable = true;

    homeManager =
      {
        config,
        pkgs,
        ...
      }:
      let
        # On standalone HM (foreign distro — e.g. Ubuntu, non-NixOS), fzf-tab's
        # prebuilt native module (fzftab.so) can't be dlopen'd: Nix .so modules don't
        # pin libc in RPATH, so the dynamic loader resolves libc.so.6 to the host's
        # system glibc, which mismatches the module's Nix libdl ("GLIBC_ABI_DT_X86_64_PLT
        # not found") — and changing the login shell to the Nix zsh doesn't help. Strip
        # the module so fzf-tab's plugin skips the zmodload + interactive rebuild prompt
        # and silently uses its pure-zsh fallback (lib/zsh-ls-colors). NixOS and the
        # nix-darwin module keep the fast native module.
        fzfTab =
          if pkgs.stdenv.hostPlatform.isLinux then
            pkgs.runCommandLocal "zsh-fzf-tab-no-native-module" { } ''
              cp -r --no-preserve=mode ${pkgs.zsh-fzf-tab} "$out"
              rm -rf "$out/share/fzf-tab/modules"
            ''
          else
            pkgs.zsh-fzf-tab;
      in
      {
        programs.zsh = {
          enable = true;
          # package = null;
          enableCompletion = true;
          dotDir = "${config.xdg.configHome}/zsh";
          initContent = ''
            # Additional history options
            setopt BANG_HIST
            setopt INC_APPEND_HISTORY
            setopt HIST_IGNORE_ALL_DUPS
            setopt HIST_FIND_NO_DUPS
            setopt HIST_SAVE_NO_DUPS
            setopt HIST_REDUCE_BLANKS
            setopt HIST_VERIFY
            setopt NO_BEEP

            # Reset leaked mouse tracking escapes (e.g. from htop in another Zellij pane)
            # before every prompt so they don't get interpreted as shell input.
            _reset_mouse_tracking() {
              printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
            }
            autoload -Uz add-zsh-hook
            add-zsh-hook precmd _reset_mouse_tracking

            # Key bindings for history search (arrow keys)
            bindkey '\e[A' history-search-backward
            bindkey '\e[B' history-search-forward

            # fzf-tab: replace zsh's completion menu with an fzf picker + previews
            # (gh0stzk-style). The plugin is loaded first in `plugins` above so it
            # wraps completion before autosuggestions/syntax-highlighting; these
            # zstyles are read at completion time so setting them here is fine.
            zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
            zstyle ':completion:*:descriptions' format '[%d]'
            zstyle ':fzf-tab:*' fzf-flags --height=90% --pointer='>'
            zstyle ':fzf-tab:*' fzf-min-height 15
            # Preview directory contents when completing cd / eza
            zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons=always --color=always -a $realpath'
            zstyle ':fzf-tab:complete:eza:*' fzf-preview 'eza -1 --icons=always --color=always -a $realpath'
            # Preview file contents when completing bat / cat / editors
            zstyle ':fzf-tab:complete:(bat|cat|nvim|vim):*' fzf-preview \
              'bat --color=always --style=numbers $realpath 2>/dev/null || eza -1 --color=always $realpath'
          ''
          # + builtins.readFile ./env.zsh
          # + builtins.readFile ./aliases.zsh
          + ''
            [ -f ${config.xdg.configHome}/op/plugins.sh ] && source ${config.xdg.configHome}/op/plugins.sh
          '';
          # Source Nix daemon profile on non-NixOS Linux.
          # The Nix installer adds this to /etc/bash.bashrc but NOT to /etc/zsh/zshenv,
          # so when zsh is the login shell, ~/.nix-profile/bin is missing from PATH.
          # Safe on NixOS too — nix-daemon.sh has a double-source guard.
          envExtra = ''
            if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
              . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
            fi
          '';
          # History — effectively unlimited (matches bash.nix), zsh has no true unlimited.
          history = {
            path = "${config.home.homeDirectory}/.local/share/zsh/history";
            size = 10000000000;
            save = 10000000000;
            ignoreSpace = true;
            ignoreDups = true;
            expireDuplicatesFirst = true;
            share = true;
            extended = true;
          };
          # oh-my-zsh
          oh-my-zsh = {
            enable = true;
            theme = ""; # disabled — Starship handles the prompt
            plugins = [
              "git"
              "kubectl"
              "history"
              "git-extras"
              "history-substring-search"
            ];
            extraConfig = ''
              HIST_STAMPS="dd.mm.yyyy"
              DISABLE_AUTO_UPDATE="true"
              zstyle ':omz:update' mode disabled
              zstyle ':omz:update' verbosity minimal
              zstyle ':completion:*' menu select
            '';
          };

          # External zsh plugins (not bundled in oh-my-zsh)
          plugins = [
            {
              # fzf-tab MUST load first: after compinit (oh-my-zsh runs it before this
              # list is sourced) but before the widget-wrapping plugins below
              # (zsh-autosuggestions / zsh-syntax-highlighting).
              name = "fzf-tab";
              src = fzfTab;
              file = "share/fzf-tab/fzf-tab.plugin.zsh";
            }
            {
              name = "zsh-autosuggestions";
              src = pkgs.zsh-autosuggestions;
              file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
            }
            {
              name = "zsh-syntax-highlighting";
              src = pkgs.zsh-syntax-highlighting;
              file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
            }
            {
              name = "zsh-history-substring-search";
              src = pkgs.zsh-history-substring-search;
              file = "share/zsh-history-substring-search/zsh-history-substring-search.zsh";
            }
            {
              name = "you-should-use";
              src = pkgs.zsh-you-should-use;
              file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
            }
          ];
        };
      };
  };
}
