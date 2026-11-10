{
  # Hyprland, a dynamic tiling Wayland compositor (NixOS), started from a greetd
  # login screen (ReGreet).
  #
  # programs.hyprland also enables polkit, XWayland, the Hyprland and GTK portals
  # and the swaylock PAM service. It is launched with `start-hyprland`, the
  # upstream launcher (it restarts Hyprland in safe mode if it crashes), rather
  # than through UWSM; Home Manager's systemd integration (below) starts
  # graphical-session.target instead.
  #
  # This aspect is the compositor alone. Hosts include one desktop shell aspect
  # instead, which includes this one and adds the bar, launcher, notifications
  # and lock screen:
  #   - hyprland-basic: waybar, fuzzel, mako and swaylock (basic.nix)
  #   - noctalia: the Noctalia shell (noctalia/)
  #   - dux-shell: Dux Shell, formerly DankMaterialShell (dux-shell/)
  # Each sets magnanix.hyprland.shell, so including two fails with a conflict.
  den.aspects.hyprland = {
    nixos =
      { config, lib, ... }:
      {
        options.magnanix.hyprland.shell = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "basic"
              "noctalia"
              "dux-shell"
            ]
          );
          default = null;
          description = "The desktop shell running on Hyprland; set by the shell aspect the host includes.";
        };

        config = {
          assertions = [
            {
              assertion = config.magnanix.hyprland.shell != null;
              message = "hyprland: include a shell aspect (hyprland-basic, noctalia or dux-shell) rather than den.aspects.hyprland directly.";
            }
          ];

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
        };
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
        # start), then hyprland.lua from this directory, then the shell
        # aspect's Lua. Edit those files to customise Hyprland.
        configType = "lua";
        extraConfig = builtins.readFile ./hyprland.lua;
      };

      # Password prompts for apps that ask polkit (1Password's system unlock,
      # for example). Runs as a user service under graphical-session.target.
      # Shells with their own polkit agent turn it off.
      services.hyprpolkitagent.enable = true;
    };
  };
}
