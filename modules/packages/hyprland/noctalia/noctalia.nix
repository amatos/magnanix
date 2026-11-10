{ den, ... }:
{
  # Noctalia (https://noctalia.dev), a desktop shell for Wayland: bar, launcher,
  # control center, notifications, lock screen, OSD and wallpaper in one
  # program. One of the Hyprland shell aspects (see hyprland.nix); fortuna
  # includes it. To try Dux Shell instead, replace den.aspects.noctalia with
  # den.aspects.dux-shell in modules/hosts/fortuna/fortuna.nix.
  #
  # Both the package and the Home Manager module come from nixpkgs and Home
  # Manager; no flake input.
  den.aspects.noctalia = {
    includes = [ den.aspects.hyprland ];

    nixos = {
      magnanix.hyprland.shell = "noctalia";

      # What Noctalia's battery and power-profile widgets talk to. Its wifi and
      # bluetooth widgets use NetworkManager and BlueZ, which hosts set up
      # themselves (fortuna has both).
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
