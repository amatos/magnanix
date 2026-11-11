# User:      alberth (den.aspects.alberth.scripts)
# Platforms: home-manager
# Purpose:   Installs the scripts in ./scripts into ~/.local/bin and puts that
#            directory on PATH (also for non-interactive `ssh host cmd`, since
#            zsh sets it in .zshenv).
#            Documented in documentation/scripts.md.
#
# Scripts:
#   control-dock.sh   -h / -s: turn Dock autohide on / off (macOS)
#   dollar.sh         runs its arguments; also installed as `$`, so a pasted
#                     `$ cmd` works in bash and zsh (a file on PATH rather
#                     than an alias: bash can't alias `$`, and fish can't run
#                     a command named `$` at all)
#   extract.sh        extracts an archive (or mounts a .dmg) by its extension
#   switch-yubikey    points gpg's key stubs at the YubiKey now inserted
#   update-all-magnanix   runs deploy-magnanix on every non-VM host in
#                     parallel (over SSH, or directly on this host) and
#                     reports the hosts that failed
#   velja-open.sh     `open "$@"`; used with the Velja browser picker
#   yubi-enable / yubi-disable   turn the OpenPGP USB interface on/off of
#                     YubiKey 32146072, which lives permanently in magnus
#                     (ykman from PATH, installed by tui.yubikey)
{
  den.aspects.alberth.scripts = {
    homeManager = { ... }: {
      # Put the scripts below (and deploy-magnanix) on PATH. Home Manager's zsh
      # sets this in .zshenv, so non-interactive `ssh host cmd` sees it too.
      home.sessionPath = [ "$HOME/.local/bin" ];

      home.file = {
        ".local/bin/control-dock.sh" = {
          source = ./scripts/control-dock.sh;
          executable = true;
        };
        ".local/bin/dollar.sh" = {
          source = ./scripts/dollar.sh;
          executable = true;
        };
        ".local/bin/$" = {
          source = ./scripts/dollar.sh;
          executable = true;
        };
        ".local/bin/extract.sh" = {
          source = ./scripts/extract.sh;
          executable = true;
        };
        ".local/bin/switch-yubikey" = {
          source = ./scripts/switch-yubikey;
          executable = true;
        };
        ".local/bin/update-all-magnanix" = {
          source = ./scripts/update-all-magnanix;
          executable = true;
        };
        ".local/bin/velja-open.sh" = {
          source = ./scripts/velja-open.sh;
          executable = true;
        };
        ".local/bin/yubi-disable" = {
          source = ./scripts/yubi-disable;
          executable = true;
        };
        ".local/bin/yubi-enable" = {
          source = ./scripts/yubi-enable;
          executable = true;
        };
      };
    };
  };
}
