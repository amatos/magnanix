# Aspect:    den.aspects.noctalia (a Hyprland shell aspect; includes hyprland)
# Platforms: nixos, home-manager
# Purpose:   Noctalia (https://noctalia.dev), a Wayland desktop shell: bar,
#            launcher, control center, notifications, lock screen, OSD and
#            wallpaper in one program. Keybinds are in ./noctalia.lua.
#
# Notes:
# - Package and Home Manager module come from nixpkgs / Home Manager; no
#   flake input.
# - Theme: a custom Dracula palette (./dracula.json): Dracula when dark,
#   Alucard when light. Noctalia also renders it into
#   ~/.config/hypr/noctalia.lua for Hyprland's window border colours.
# - config.toml is read-only defaults; changes made in Noctalia's settings
#   window are kept on top of them.
# - upower and power-profiles-daemon back its battery and power-profile
#   widgets. Wi-Fi and Bluetooth widgets need NetworkManager and BlueZ, which
#   the host must enable itself.
# - To switch shells, replace den.aspects.noctalia in the host's includes with
#   another shell aspect (hyprland-basic, dux-shell).
{ den, ... }:
{
  den.aspects.noctalia = {
    includes = [ den.aspects.hyprland ];

    nixos = {
      magnanix.hyprland.shell = "noctalia";

      # What Noctalia's battery and power-profile widgets talk to. Its wifi and
      # bluetooth widgets use NetworkManager and BlueZ, which hosts set up
      # themselves.
      services.upower.enable = true;
      services.power-profiles-daemon.enable = true;
    };

    homeManager =
      { lib, ... }:
      {
        programs.noctalia = {
          enable = true;

          # Defaults, written to ~/.config/noctalia/config.toml (read-only).
          # Changes made in Noctalia's settings window are kept on top of them.
          settings.theme = {
            mode = "dark";

            # A palette built from Dracula's official colors (dracula.json):
            # Dracula when dark, Alucard (Dracula's light theme) when light.
            source = "custom";
            custom_palette = "Dracula";

            # Renders the palette into ~/.config/hypr/noctalia.lua, which
            # noctalia.lua loads for the window border colors.
            templates = {
              enable_builtin_templates = true;
              builtin_ids = [ "hyprland" ];
            };
          };

          # ~/.config/noctalia/palettes/Dracula.json
          customPalettes.Dracula = ./dracula.json;
        };

        wayland.windowManager.hyprland.extraConfig = lib.mkAfter (builtins.readFile ./noctalia.lua);
      };
  };
}
