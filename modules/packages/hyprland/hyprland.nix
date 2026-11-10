# Aspect:    den.aspects.hyprland (don't include directly; include a shell aspect)
# Platforms: nixos, home-manager
# Purpose:   Hyprland, a dynamic tiling Wayland compositor, started from a greetd
#            login screen (ReGreet), with gnome-keyring and the Hyprland polkit
#            agent. The shared Hyprland config is ./hyprland.lua.
#
# Notes:
# - This is the compositor alone. A host includes exactly one desktop shell
#   aspect, which includes this one and adds the bar, launcher, notifications
#   and lock screen:
#     hyprland-basic  waybar, fuzzel, mako, swaylock      (basic/)
#     noctalia        the Noctalia shell                  (noctalia/)
#     dux-shell       Dux Shell, formerly DankMaterialShell (dux-shell/)
#   Each sets magnanix.hyprland.shell, so including two fails with a conflict,
#   and including none fails an assertion.
# - Launched with `start-hyprland` (upstream's launcher, which restarts
#   Hyprland in safe mode after a crash) rather than UWSM. Home Manager's
#   systemd integration starts graphical-session.target instead.
# - programs.hyprland also enables polkit, XWayland, the Hyprland and GTK
#   portals and swaylock's PAM service.
# - gnome-keyring is enabled because, unlike niri, Hyprland doesn't do it
#   itself; it's unlocked at login through greetd's PAM stack.
# - The config is Lua (Hyprland 0.55+), written read-only to
#   ~/.config/hypr/hyprland.lua: systemd integration, then ./hyprland.lua, then
#   the shell aspect's Lua. Edit the .lua files here, not in ~/.config.
{
  den.aspects.hyprland = {
    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
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
          # Themed with Dracula's GTK and icon themes from nixpkgs (Dracula PRO
          # lives in a per-user checkout the greeter can't read).
          services.displayManager.regreet = {
            enable = true;
            theme = {
              package = pkgs.dracula-theme;
              name = "Dracula";
            };
            iconTheme = {
              package = pkgs.dracula-icon-theme;
              name = "Dracula";
            };
          };
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
