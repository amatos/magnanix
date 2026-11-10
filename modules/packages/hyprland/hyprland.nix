{
  # Hyprland, a dynamic tiling Wayland compositor (NixOS), started from a greetd
  # login screen (ReGreet).
  #
  # programs.hyprland also enables polkit, XWayland, the Hyprland and GTK portals
  # and the swaylock PAM service. It is launched with `start-hyprland`, the
  # upstream launcher (it restarts Hyprland in safe mode if it crashes), rather
  # than through UWSM; Home Manager's systemd integration (below) starts
  # graphical-session.target instead.
  den.aspects.hyprland = {
    nixos =
      { pkgs, ... }:
      {
        programs.hyprland = {
          enable = true;
          xwayland.enable = true;
        };

        # niri turns this on by itself; Hyprland doesn't. It keeps secrets for
        # browsers and other apps, unlocked at login through greetd's PAM stack.
        services.gnome.gnome-keyring.enable = true;

        # ReGreet, a graphical (GTK4) greeter. The module enables greetd and runs
        # ReGreet in cage, a kiosk compositor. It lists the installed sessions
        # (Hyprland's runs start-hyprland) and remembers the last user and session.
        services.displayManager.regreet.enable = true;

        environment.systemPackages = [
          # What hyprland.lua spawns (besides the terminal, Ghostty)
          pkgs.fuzzel # Super+R: application launcher
          pkgs.swaylock # Super+L: screen locker
          pkgs.waybar # status bar, started at login

          pkgs.mako # notifications (started on demand over D-Bus)
        ];
      };

    homeManager = {
      wayland.windowManager.hyprland = {
        enable = true;

        # Installed by programs.hyprland above, which also sets up the portal.
        package = null;
        portalPackage = null;

        # Hyprland 0.55+ reads hyprland.lua. Home Manager writes it to
        # ~/.config/hypr/hyprland.lua (read-only, in the store): first the
        # systemd integration (hyprland-session.target, bound to
        # graphical-session.target, so user services like the polkit agent
        # start), then hyprland.lua from this directory. Edit that file to
        # customise Hyprland.
        configType = "lua";
        extraConfig = builtins.readFile ./hyprland.lua;
      };

      # Password prompts for apps that ask polkit (1Password's system unlock,
      # for example). Runs as a user service under graphical-session.target.
      services.hyprpolkitagent.enable = true;
    };
  };
}
