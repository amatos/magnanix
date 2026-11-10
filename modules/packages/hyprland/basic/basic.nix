# Aspect:    den.aspects.hyprland-basic (a Hyprland shell aspect; includes hyprland)
# Platforms: nixos, home-manager
# Purpose:   Hyprland with separate small tools for the desktop: waybar (status
#            bar), fuzzel (Super+R launcher), swaylock (Super+L) and mako
#            (notifications, started on demand over D-Bus). Keybinds are in
#            ./basic.lua.
{ den, ... }:
{
  den.aspects.hyprland-basic = {
    includes = [ den.aspects.hyprland ];

    nixos =
      { pkgs, ... }:
      {
        magnanix.hyprland.shell = "basic";

        environment.systemPackages = [
          pkgs.fuzzel
          pkgs.swaylock
          pkgs.waybar
          pkgs.mako # started on demand over D-Bus
        ];
      };

    homeManager =
      { lib, ... }:
      {
        wayland.windowManager.hyprland.extraConfig = lib.mkAfter (builtins.readFile ./basic.lua);
      };
  };
}
