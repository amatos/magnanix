# Aspect:    den.aspects.dux-shell (a Hyprland shell aspect; includes hyprland)
# Platforms: nixos, home-manager
# Purpose:   Dux Shell (https://duxlabs.dev), formerly DankMaterialShell (DMS):
#            a Quickshell desktop shell with bar, launcher, control center,
#            dock, notifications, lock screen, OSD, clipboard history and its
#            own polkit agent. Keybinds are in ./dux-shell.lua.
#
# Notes:
# - The rename kept the `dms` command, the dms.service unit and the
#   ~/.config/dms and ~/.config/hypr/dms directories.
# - Package and NixOS module come from nixpkgs; no flake input. Home Manager
#   has no Dux module, so settings.json is seeded once (see below) and is Dux's
#   to change after that. Delete it and switch to reseed.
# - `dms setup` is blocked (via /etc/dms/cli-policy.json), because it would
#   try to replace the Nix-managed hyprland.lua. On first login, close the
#   welcome screen. A "First Time Setup" banner on the keybinds page can be
#   ignored: edits there go to dms/binds-user.lua, which is loaded.
# - Theme: a custom Dracula palette (./dracula.json): Dracula when dark,
#   Alucard when light.
# - Wi-Fi, Bluetooth and audio widgets need NetworkManager, BlueZ and
#   PipeWire, which the host must enable itself.
{ den, ... }:
{
  den.aspects.dux-shell = {
    includes = [ den.aspects.hyprland ];

    nixos = {
      magnanix.hyprland.shell = "dux-shell";

      # Installs dux-shell (the `dms` command), Quickshell, matugen and cava,
      # and enables accounts-daemon (user avatar) and i2c (external monitor
      # brightness). Its dms.service user unit is wanted by
      # graphical-session.target, which Home Manager's Hyprland integration
      # starts at login (hyprland-session.target binds it), so the shell starts
      # there exactly once; dux-shell.lua doesn't start it.
      programs.dux-shell.enable = true;

      # What Dux's battery and power-profile widgets talk to, and the location
      # source for its weather and automatic night mode. Its wifi, bluetooth
      # and audio widgets use NetworkManager, BlueZ and PipeWire, which hosts
      # set up themselves.
      services.upower.enable = true;
      services.power-profiles-daemon.enable = true;
      services.geoclue2.enable = true;

      # `dms setup` deploys Dux's own ~/.config/hypr/hyprland.lua, which here is
      # Home Manager's read-only file. Dux's CLI policy can block commands; it
      # applies the block list only on systems it treats as immutable, so mark
      # this one as such. Blocks `dms setup` and its subcommands, nothing else.
      environment.etc."dms/cli-policy.json".text = builtins.toJSON {
        policy_version = 1;
        immutable_system = true;
        blocked_commands = [ "setup" ];
        message = "Hyprland's config is managed by Nix (modules/packages/hyprland); edit it there instead.";
      };
    };

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        themeFile = "${config.xdg.configHome}/dms/custom-themes/dracula.json";
        settingsFile = "${config.xdg.configHome}/dms/settings.json";

        # First-run settings: the Dracula theme, and natural scrolling on, to
        # match the shared Hyprland config (dux-shell.lua keeps it on anyway).
        initialSettings = pkgs.writeText "dux-shell-settings.json" (
          builtins.toJSON {
            currentThemeCategory = "custom";
            currentThemeName = "custom";
            customThemeFile = themeFile;
            mouseNaturalScroll = true;
            touchpadNaturalScroll = true;
          }
        );
      in
      {
        wayland.windowManager.hyprland = {
          extraConfig = lib.mkAfter (builtins.readFile ./dux-shell.lua);

          # Apps opened from Dux's launcher inherit the environment of its
          # systemd service, not Hyprland's, so pass all of Hyprland's
          # environment to systemd, as Dux's own hyprland.lua does.
          systemd.variables = [ "--all" ];
        };

        # Dux runs its own polkit agent; a second one would compete with it.
        services.hyprpolkitagent.enable = lib.mkForce false;

        # A palette built from Dracula's official colors (dracula.json): Dracula
        # when dark, Alucard (Dracula's light theme) when light. Not in
        # ~/.config/dms/themes/, which holds themes installed from Dux's browser.
        xdg.configFile."dms/custom-themes/dracula.json".source = ./dracula.json;

        # Dux writes ~/.config/dms/settings.json from its settings window, so it
        # can't be a read-only file from the store. Seed it once instead: written
        # only when it doesn't exist, after which it's Dux's (and later changes
        # here don't reach it). To reseed, delete the file and switch again.
        home.activation.duxShellSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ ! -e ${lib.escapeShellArg settingsFile} ]; then
            run mkdir -p ${lib.escapeShellArg (dirOf settingsFile)}
            run install -m 644 ${initialSettings} ${lib.escapeShellArg settingsFile}
          fi
        '';
      };
  };
}
