{
  # niri, a scrollable-tiling Wayland compositor (NixOS), started from a greetd
  # login screen (tuigreet).
  #
  # programs.niri also enables polkit, the GNOME portal, gnome-keyring and the
  # swaylock PAM service. niri runs xwayland-satellite itself, for X11 apps,
  # when it is on PATH.
  den.aspects.niri = {
    nixos =
      { pkgs, ... }:
      {
        programs.niri.enable = true;

        services.greetd = {
          enable = true;
          settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --cmd niri-session";
        };

        environment.systemPackages = [
          # What niri's default config spawns (besides the terminal, see below)
          pkgs.fuzzel # Mod+D: application launcher
          pkgs.swaylock # Super+Alt+L: screen locker
          pkgs.waybar # status bar, started at login

          pkgs.mako # notifications
          pkgs.xwayland-satellite # X11 apps
        ];
      };

    # niri's default config, with Ghostty as the Mod+T terminal instead of
    # alacritty. The file is read-only (it is in the store); to customise niri,
    # replace this with a config.kdl kept in the repo.
    homeManager =
      { pkgs, ... }:
      {
        xdg.configFile."niri/config.kdl".source = pkgs.runCommand "niri-config.kdl" { } ''
          sed 's/spawn "alacritty"/spawn "ghostty"/; s/Open a Terminal: alacritty/Open a Terminal: ghostty/' \
            ${pkgs.niri.src}/resources/default-config.kdl > $out
        '';
      };
  };
}
