{ den, ... }:
{
  # Hyprland with separate tools for the desktop: waybar (status bar), fuzzel
  # (Super+R launcher), swaylock (Super+L) and mako (notifications). One of the
  # Hyprland shell aspects; see hyprland.nix.
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
