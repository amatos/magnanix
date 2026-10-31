{
  # `trash` (trash-cli) from nixpkgs, so a trash command is always available
  # (macOS only ships /usr/bin/trash from 14 onwards; Linux has none by default).
  # Also used by the Home Manager backupCommand in modules/den/home-manager.nix.
  den.aspects.tui.trash = {
    os =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.trash-cli ];
      };
  };
}
