# Aspect:    den.aspects.game-streaming
# Platforms: nixos, darwin
# Purpose:   Game streaming without anyone logging in at the console. On NixOS
#            (the host): Sunshine and Steam in a headless Sway session, started
#            and stopped over SSH with `game-session`. On macOS (the client):
#            Moonlight.
#
# Notes:
# - `game-session start [--desktop] [WIDTHxHEIGHT[@RATE]]` starts the
#   game-session user service: Sway with a virtual output (1920x1080@60 by
#   default), Sunshine capturing it and Steam in Big Picture mode.
#   `game-session stop` ends all three. It's Sway rather than Hyprland, so it
#   can't collide with the normal desktop session.
# - `--desktop` starts the regular Steam client instead, and leaves windows
#   tiled rather than fullscreen, so companion tools (Elite Dangerous's
#   EDMarketConnector and the like) can run next to the game. It adds Super
#   keybindings, a bar, Ghostty (Super+Return) and fuzzel (Super+D).
# - Steam is single-instance: quit it in the Hyprland session first, or the
#   game session's `steam` just forwards to that one. `start` refuses if it's
#   running.
# - Sway reads input through libinput with LIBSEAT_BACKEND=noop (no logind
#   seat exists over SSH), so the user joins `input` (read all input devices)
#   and `uinput` (create Sunshine's virtual ones). That also means a keyboard
#   or mouse at the host's desk reaches the game session, and Sunshine's
#   virtual devices reach Hyprland if it's logged in.
# - The user lingers, so their systemd manager (and the session, and PipeWire)
#   keeps running after the SSH connection closes.
# - Sunshine's ports are open on tailscale0 only, except the web UI (47990):
#   reach it through `ssh -L 47990:localhost:47990 <host>`. The settings are
#   read-only (they come from this file); credentials, paired clients and
#   apps.json live in ~/.config/sunshine.
# - Sunshine's own sunshine.service is installed but not started
#   (autoStart = false); game-session runs Sunshine inside Sway instead.
# - First-time setup is in documentation/game-streaming.md.
let
  defaultMode = "1920x1080@60Hz";
  # Sunshine's base port and the offsets it listens on, minus the web UI (+1).
  basePort = 47989;
  tcpOffsets = [
    (-5)
    0
    21
  ];
  udpOffsets = [
    9
    10
    11
    13
    21
  ];
in
{
  den.aspects.game-streaming = {
    darwin.homebrew.casks = [ "moonlight" ];

    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        sunshine = config.services.sunshine.package;

        sunshineConfig = (pkgs.formats.keyValue { }).generate "sunshine.conf" {
          sunshine_name = config.networking.hostName;
          port = basePort;
          # Capture the Sway output through wlr-screencopy and encode on the GPU.
          capture = "wlr";
          encoder = "vaapi";
        };

        steam = lib.getExe config.programs.steam.package;

        # Shared by both kinds of session. The output mode comes first, from
        # the file game-session-run writes. No idle, no screen locking: nobody
        # is at this display.
        swayCommon = ''
          exec ${lib.getExe sunshine} ${sunshineConfig}
        '';

        swayConfigs = {
          bigpicture = pkgs.writeText "game-session-bigpicture.conf" ''
            ${swayCommon}
            default_border none
            default_floating_border none
            # Every window (Big Picture, games, launchers) fills the screen.
            for_window [all] fullscreen enable

            exec ${steam} -gamepadui
          '';

          # A small tiling desktop: the regular Steam client, with room for
          # tools next to the game.
          desktop = pkgs.writeText "game-session-desktop.conf" ''
            ${swayCommon}
            set $mod Mod4
            floating_modifier $mod normal
            default_border pixel 2

            bindsym $mod+Return exec ${lib.getExe pkgs.ghostty}
            bindsym $mod+d exec ${lib.getExe pkgs.fuzzel}
            bindsym $mod+Shift+q kill
            bindsym $mod+f fullscreen toggle
            bindsym $mod+Shift+space floating toggle
            bindsym $mod+e layout toggle split
            bindsym $mod+w layout tabbed

            bindsym $mod+Left focus left
            bindsym $mod+Down focus down
            bindsym $mod+Up focus up
            bindsym $mod+Right focus right
            bindsym $mod+Shift+Left move left
            bindsym $mod+Shift+Down move down
            bindsym $mod+Shift+Up move up
            bindsym $mod+Shift+Right move right

            ${lib.concatMapStrings (n: ''
              bindsym $mod+${n} workspace number ${n}
              bindsym $mod+Shift+${n} move container to workspace number ${n}
            '') (map toString (lib.range 1 4))}
            bar {
              position top
              status_command while date +'%Y-%m-%d %H:%M'; do sleep 30; done
            }

            exec ${steam}
          '';
        };

        # Writes the Sway config with the output mode and kind of session
        # chosen by `game-session start` (or the defaults) and runs Sway.
        runSession = pkgs.writeShellApplication {
          name = "game-session-run";
          runtimeInputs = [ pkgs.sway ];
          text = ''
            state="$XDG_RUNTIME_DIR/game-session"
            mkdir -p "$state"
            mode="$(cat "$state/mode" 2>/dev/null || echo ${lib.escapeShellArg defaultMode})"
            case "$(cat "$state/kind" 2>/dev/null || echo bigpicture)" in
              desktop) include=${swayConfigs.desktop} ;;
              *) include=${swayConfigs.bigpicture} ;;
            esac
            {
              echo "output HEADLESS-1 mode $mode"
              echo "include $include"
            } >"$state/sway.conf"
            exec sway --config "$state/sway.conf"
          '';
        };

        gameSession = pkgs.writeShellApplication {
          name = "game-session";
          runtimeInputs = [
            pkgs.procps
            pkgs.systemd
          ];
          text = ''
            unit=game-session.service

            usage() {
              cat <<'EOF'
            Usage: game-session start [--desktop] [WIDTHxHEIGHT[@RATE]]   (default ${defaultMode})
                   game-session stop
                   game-session status
                   game-session logs
            EOF
            }

            case "''${1:-status}" in
              start)
                shift
                kind=bigpicture
                if [[ "''${1:-}" == --desktop ]]; then
                  kind=desktop
                  shift
                fi
                mode="''${1:-${defaultMode}}"
                if [[ ! "$mode" =~ ^([0-9]+x[0-9]+)(@([0-9]+(\.[0-9]+)?)(Hz)?)?$ ]]; then
                  echo "game-session: '$mode' isn't WIDTHxHEIGHT or WIDTHxHEIGHT@RATE" >&2
                  exit 2
                fi
                mode="''${BASH_REMATCH[1]}@''${BASH_REMATCH[3]:-60}Hz"

                if systemctl --user --quiet is-active "$unit"; then
                  echo "game-session: already running (game-session stop first to change the mode)"
                  exit 0
                fi
                if pgrep -u "$(id -u)" -x steam >/dev/null; then
                  echo "game-session: Steam is already running, probably in the desktop session; quit it first" >&2
                  exit 1
                fi

                mkdir -p "$XDG_RUNTIME_DIR/game-session"
                echo "$mode" >"$XDG_RUNTIME_DIR/game-session/mode"
                echo "$kind" >"$XDG_RUNTIME_DIR/game-session/kind"
                systemctl --user start "$unit"
                echo "game-session: started $kind at $mode; connect with Moonlight"
                ;;
              stop)
                systemctl --user stop "$unit"
                echo "game-session: stopped"
                ;;
              status)
                systemctl --user --no-pager status "$unit"
                ;;
              logs)
                journalctl --user --no-pager -u "$unit" -n 100
                ;;
              -h | --help | help)
                usage
                ;;
              *)
                usage >&2
                exit 2
                ;;
            esac
          '';
        };
      in
      {
        assertions = [
          {
            assertion = config.programs.steam.enable;
            message = "game-streaming: include den.aspects.steam on this host too.";
          }
        ];

        services.sunshine = {
          enable = true;
          # Run inside the game session, not in every graphical session.
          autoStart = false;
        };

        networking.firewall.interfaces.${config.services.tailscale.interfaceName} = {
          allowedTCPPorts = map (offset: basePort + offset) tcpOffsets;
          allowedUDPPorts = map (offset: basePort + offset) udpOffsets;
        };

        environment.systemPackages = [ gameSession ];

        systemd.user.services.game-session = {
          description = "Headless Sway session running Sunshine and Steam";
          environment = {
            # A virtual output, plus libinput for Sunshine's virtual input devices.
            # There's no logind seat over SSH, so libinput opens devices directly
            # (hence the input group).
            WLR_BACKENDS = "headless,libinput";
            WLR_LIBINPUT_NO_DEVICES = "1";
            LIBSEAT_BACKEND = "noop";
            XDG_CURRENT_DESKTOP = "sway";
            XDG_SESSION_TYPE = "wayland";
            # Steam and games look up helpers (xdg-open and so on) on PATH.
            PATH = lib.mkForce "/run/wrappers/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";
            # fuzzel (and Steam) find .desktop files and icons through it.
            XDG_DATA_DIRS = "/etc/profiles/per-user/%u/share:/run/current-system/sw/share";
          };
          serviceConfig = {
            ExecStart = lib.getExe runSession;
            TimeoutStopSec = 30;
          };
        };
      };

    includes = [
      (
        { user, ... }:
        {
          nixos.users.users.${user.userName} = {
            linger = true;
            extraGroups = [
              "input"
              "uinput"
            ];
          };
        }
      )
    ];
  };
}
