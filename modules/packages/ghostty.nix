# Aspects:   den.aspects.ghostty           (the terminal)
#            den.aspects.ghostty.terminfo  (included by base)
# Platforms: ghostty: home-manager; terminfo: nixos, darwin
# Purpose:   Ghostty terminal and its config. `terminfo` installs Ghostty's
#            terminfo system-wide, so every host can serve SSH sessions coming
#            from Ghostty even if it doesn't run Ghostty itself.
#
# Notes (changes from Ghostty's defaults):
# - Theme: built-in Dracula. Users with magnanix.draculaPro get Dracula PRO's
#   colors layered on through an optional include (`?` prefix), so a missing
#   checkout falls back to Dracula instead of an error.
# - Font size 14 (default 13).
# - copy-on-select = "clipboard": selections also go to the system clipboard,
#   so Cmd-V and other apps can paste them.
# - Shell integration adds sudo (keep terminfo under sudo), ssh-terminfo
#   (install terminfo on remote hosts) and ssh-env (fall back to
#   TERM=xterm-256color where that's impossible).
# - macOS uses `ghostty-bin` (the upstream app bundle); `ghostty` doesn't
#   build there.
{
  den.aspects.ghostty = {
    # Lets hosts that don't run Ghostty still serve SSH sessions coming from it.
    terminfo = {
      nixos = { pkgs, ... }: {
        environment.systemPackages = [ pkgs.ghostty.terminfo ];
      };

      darwin = { pkgs, ... }: {
        environment.systemPackages = [ pkgs.ghostty-bin.terminfo ];
      };
    };

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        # Users who own Dracula PRO opt in with `magnanix.draculaPro` (see
        # modules/den/dracula-pro.nix); everyone else gets Ghostty's built-in Dracula.
        # The flagship `pro` variant is included over Dracula (see `config-file`
        # below), and each PRO variant is symlinked into ~/.config/ghostty/themes
        # as `dracula-pro-<variant>` (`pro` as plain `dracula-pro`).
        draculaPro = config.magnanix.draculaPro;
        draculaProThemes = "${draculaPro.dir}/themes/ghostty";
        draculaProVariants = [
          "pro"
          "alucard"
          "blade"
          "buffy"
          "lincoln"
          "morbius"
          "nosferatu"
          "van-helsing"
        ];
        themeName = variant: if variant == "pro" then "dracula-pro" else "dracula-pro-${variant}";
      in
      {
        programs.ghostty = {
          enable = true;
          # The `ghostty` package doesn't build on macOS; `ghostty-bin` is the upstream app bundle.
          package = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;

          # Written to ~/.config/ghostty/config and checked with
          # `ghostty +validate-config` whenever it changes.
          settings = {
            # Ghostty's built-in Dracula, always available.
            theme = "Dracula";

            # Dracula PRO's colors on top, when the checkout exists. The leading `?`
            # makes the include optional: before the checkout is cloned (a fresh
            # host, where activation can't reach GitHub) Ghostty silently keeps
            # Dracula instead of failing on a missing theme. Included files load
            # after this config, and their colors override the theme's.
            config-file = lib.mkIf draculaPro.enable "?${draculaProThemes}/pro";

            # Ghostty's default is 13.
            font-size = 14;

            # Ghostty's default (`true`) copies selections only to its own selection
            # clipboard, which macOS lacks a system equivalent of; `clipboard` also
            # copies to the system clipboard, so Cmd+V and other apps can paste it.
            copy-on-select = "clipboard";

            # Added to Ghostty's defaults (listed features are toggled, the rest
            # keep their defaults). `sudo` keeps Ghostty's terminfo under sudo;
            # `ssh-terminfo` installs it on remote hosts on first connect, for
            # machines outside magnanix that lack the `terminfo` part above;
            # `ssh-env` falls back to TERM=xterm-256color where that's impossible.
            shell-integration-features = "sudo,ssh-env,ssh-terminfo";
          };
        };

        # Lets modules/den/dracula-pro.nix clone the checkout on this host.
        magnanix.draculaPro.usedBy = lib.mkIf draculaPro.enable [ "ghostty" ];

        # The PRO variants as named themes, to try one by hand (for example
        # `theme = dracula-pro-blade`). Nothing in the generated config names them,
        # so these links dangling before the checkout exists is harmless.
        xdg.configFile = lib.mkIf draculaPro.enable (
          lib.listToAttrs (
            map (
              variant:
              lib.nameValuePair "ghostty/themes/${themeName variant}" {
                source = config.lib.file.mkOutOfStoreSymlink "${draculaProThemes}/${variant}";
              }
            ) draculaProVariants
          )
        );
      };
  };
}
