# Aspect:    den.aspects.tui.trash (included by base)
# Platforms: nixos, darwin
# Purpose:   trash-cli (`trash`, `trash-list`, `trash-restore`), so files can be
#            moved to the trash instead of deleted on every host.
#
# Notes:
# - macOS only ships /usr/bin/trash from 14 on, and Linux has none by default.
# - Home Manager's backupCommand (modules/den/home-manager.nix) uses it.
{
  den.aspects.tui.trash = {
    os =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.trash-cli ];
      };
  };
}
