# Aspect:    den.aspects.shell.fish (included by base)
# Platforms: home-manager, nixos, darwin
# Purpose:   fish, at user level (Home Manager) and system level, with the shared
#            aliases, the fish versions of the shell functions and Starship.
#
# Notes:
# - Home Manager: no greeting; `autopair` (auto-closes brackets and quotes) and
#   `bass` (runs bash scripts and keeps their env changes, used here to source
#   1Password's op/plugins.sh) plugins.
# - NixOS: fish becomes users.defaultUserShell. A user's own
#   users.users.<name>.shell overrides it.
# - System-level aliases and functions are per OS. NixOS: xclip clipboard
#   aliases, and functions for PulseAudio restarts, DNS/network resets and
#   ntp-force-update (programs.fish.shellFunctions). macOS: pbcopy aliases, and
#   `tail-exit-node-fix` (clears stuck Tailscale exit-node routes), defined in
#   interactiveShellInit because nix-darwin has no shellFunctions option.
{ den, ... }:
{
  den.aspects.shell.fish = {
    includes = [
      den.aspects.shell.shellAliases
      den.aspects.shell.fishFunctions
      den.aspects.shell.starship
    ];
    homeManager =
      { pkgs, config, ... }:
      {
        home.shell.enableFishIntegration = true;

        programs = {
          fish = {
            enable = true;

            functions = {
              fish_greeting = "";
            };

            plugins = [
              {
                name = "autopair";
                src = pkgs.fishPlugins.autopair;
              }
              {
                name = "bass";
                src = pkgs.fishPlugins.bass.src;
              }
            ];

            shellAliases = {
              # Pipeline — keep in shellAliases (fish handles pipelines in aliases)
              ducks = "echo '🦆 Showing top large files/folders...' && sudo du -ckhs * | sort -rn | head";
              # Backwards-compat zsh muscle-memory
              ez = "exec fish";

              # zoxide alias (z/j short form). zoxide's fish integration provides z; j is muscle-memory.
              j = "z";
            };

            interactiveShellInit = ''
              if test -f ${config.xdg.configHome}/op/plugins.sh
                bass source ${config.xdg.configHome}/op/plugins.sh
              end
            '';
          };
        };
      };

    nixos =
      { pkgs, ... }:
      {
        programs.fish = {
          enable = true;

          shellAliases = {
            clipboard = "xclip -selection clipboard -i";
            paste = "xclip -selection clipboard -o";
            pbcopy = "xclip -selection clipboard";
            pbpaste = "xclip -selection clipboard -o";
          };

          # Multi-line helpers are fish functions, not aliases: an alias is a
          # one-line command, so these bodies didn't work as shellAliases.
          # Each function's code goes in its `body`.
          shellFunctions = {
            # ── PulseAudio ─────────────────────────────────────────────────────────
            pulse-restart.body = ''
              echo "🔧 Attempting PulseAudio restart..."
              if pulseaudio --check
                echo "✅ PulseAudio is running. Restarting gracefully..."
                pulseaudio -k
              else
                echo "⚠️ PulseAudio not detected. Trying force kill..."
                sudo killall pulseaudio 2>/dev/null
              end
              echo "🎵 Restart complete. You may need to wait a few seconds."
            '';

            pulse-restart-systemd.body = ''
              echo "🔄 Restarting PulseAudio via systemd..."
              systemctl --user restart pulseaudio
            '';

            pulse-restart-safe.body = ''
              echo "🔍 Checking PulseAudio status..."
              if pulseaudio --check
                echo "✅ PulseAudio is running. Restarting..."
                pulseaudio -k
              else
                echo "⚠️ PulseAudio not running or already stopped."
              end
            '';

            pulse-restart-force.body = ''
              echo "🛑 Forcing PulseAudio to restart..."
              pulseaudio -k; or sudo killall pulseaudio
              echo "✅ PulseAudio forcibly restarted."
            '';

            # ── DNS / network ──────────────────────────────────────────────────────
            dns-reset1.body = ''
              echo "🔁 Restarting basic DNS components..."
              sudo systemctl restart systemd-resolved; and echo "✅ systemd-resolved restarted."
              sudo systemctl restart resolvconf; and echo "✅ resolvconf restarted."
              echo "✅ DNS basic reset complete."
            '';

            full-network-reset.body = ''
              echo "🚨 Starting FULL NETWORK RESET..."
              tail-vpn-restart
              echo "🔁 Resetting DNS..."
              dns-reset-all
              echo
              echo "🌐 Checking internet connectivity..."
              if ping -c 2 1.1.1.1 >/dev/null 2>&1
                echo "✅ Internet is reachable."
              else
                echo "❌ No internet connection detected."
              end
              echo "🧩 Full network stack reset complete."
            '';

            # Sets the clock from the Date header of an HTTP response from
            # google.com, for when NTP is unreachable.
            ntp-force-update.body = ''
              echo "🕒 Forcing time sync with Google..."
              and sudo date -s (wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d" " -f5-8)"Z"
              and echo "✅ Time updated from HTTP headers."
            '';
          };

          interactiveShellInit = "";
        };
        users.defaultUserShell = pkgs.fish;
      };

    darwin =
      { pkgs, ... }:
      {
        programs = {
          # man.generateCaches = false;
          fish = {
            enable = true;
            shellAliases = {
              clipboard = "pbcopy";
              paste = "pbpaste";
            };

            # nix-darwin's programs.fish has no shellFunctions option, so the
            # function is defined in the system config.fish instead.
            #
            # An exit node disabled while unhealthy can leave tailscaled's
            # full-tunnel override routes (0.0.0.0/1, 128.0.0.0/1) stuck in the
            # routing table, and dns-reset-all won't touch them. This checks for
            # the stuck routes and, if found, kickstarts tailscaled and bounces the
            # tunnel to clear them, instead of unplugging Ethernet.
            interactiveShellInit = ''
              function tail-exit-node-fix --description "Clear stuck Tailscale exit-node routes"
                  echo "🔍 Checking for stuck exit-node routes..."
                  set -l stuck (netstat -rn -f inet | grep -E '^(0(\.0\.0\.0)?|128(\.0\.0\.0)?)/1[[:space:]]')
                  if test -z "$stuck"
                      echo "✅ No stuck full-tunnel routes found — routing looks clean."
                      return 0
                  end
                  echo "🚨 Found leftover exit-node routes:"
                  printf "%s\n" $stuck
                  echo "🔄 Kickstarting tailscaled..."
                  sudo launchctl kickstart -k system/com.tailscale.tailscaled
                  sleep 2
                  tail-vpn-restart
                  echo "🔍 Re-checking routes..."
                  set -l stuck (netstat -rn -f inet | grep -E '^(0(\.0\.0\.0)?|128(\.0\.0\.0)?)/1[[:space:]]')
                  if test -z "$stuck"
                      echo "✅ Stuck routes cleared."
                  else
                      echo "❌ Routes still present — try toggling Wi-Fi/Ethernet, or reboot."
                      printf "%s\n" $stuck
                  end
              end
            '';
          };
        };
      };
  };
}
