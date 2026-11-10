# Aspect:    den.aspects.niri
# Platforms: nixos, home-manager
# Purpose:   niri, a scrollable-tiling Wayland compositor, started from a greetd
#            login screen (tuigreet), with fuzzel, swaylock, waybar and mako.
#            Kept as an alternative to Hyprland.
#
# Notes:
# - Uses niri's stock config, with Ghostty instead of alacritty on Mod+T. It is
#   read-only (generated in the store); to customise niri, replace it with a
#   config.kdl kept in this repo.
# - programs.niri also enables polkit, the GNOME portal, gnome-keyring and the
#   swaylock PAM service. xwayland-satellite gives X11 apps a display.
{
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
