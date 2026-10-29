{ den, ... }: {
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
              op completion fish | source
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
            # ── PulseAudio (Linux-only) ────────────────────────────────────────────
            pulse-restart = ''
              if test (uname) = Darwin
                echo "PulseAudio control is Linux-only."
                return 1
              end
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

            pulse-restart-systemd = ''
              echo "🔄 Restarting PulseAudio via systemd..."
              systemctl --user restart pulseaudio
            '';

            pulse-restart-safe = ''
              echo "🔍 Checking PulseAudio status..."
              if pulseaudio --check
                echo "✅ PulseAudio is running. Restarting..."
                pulseaudio -k
              else
                echo "⚠️ PulseAudio not running or already stopped."
              end
            '';

            pulse-restart-force = ''
              echo "🛑 Forcing PulseAudio to restart..."
              pulseaudio -k; or sudo killall pulseaudio
              echo "✅ PulseAudio forcibly restarted."
            '';

            # ── DNS / network ──────────────────────────────────────────────────────
            dns-reset1 = ''
              if test (uname) = Darwin
                echo "dns-reset1 is Linux-only."
                return 1
              end
              echo "🔁 Restarting basic DNS components..."
              sudo systemctl restart systemd-resolved; and echo "✅ systemd-resolved restarted."
              sudo systemctl restart resolvconf; and echo "✅ resolvconf restarted."
              echo "✅ DNS basic reset complete."
            '';
            full-network-reset = ''
              if test (uname) = Darwin
                echo "Full network reset is Linux-only."
                return 1
              end
              echo "🚨 Starting FULL NETWORK RESET..."
              tail-vpn-restart
              echo "🔁 Resetting DNS..."
              dns-reset-all
              echo "📶 Reloading Wi-Fi module..."
              reload-wifi-mt7921
              echo
              echo "🌐 Checking internet connectivity..."
              if ping -c 2 1.1.1.1 >/dev/null 2>&1
                echo "✅ Internet is reachable."
              else
                echo "❌ No internet connection detected."
              end
              echo "🧩 Full network stack reset complete."
              alias ntp-force-update='echo "🕒 Forcing time sync with Google..." && sudo date -s (wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d" " -f5-8)"Z" && echo "✅ Time updated from HTTP headers."'
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
              build-darwin = "build-nix";
              switch-darwin = "switch-nix";

              clipboard = "pbcopy";
              paste = "pbpaste";

              # ── DNS / network ──────────────────────────────────────────────────────
              # macOS-only. An exit node disabled while unhealthy can leave
              # tailscaled's full-tunnel override routes (0.0.0.0/1, 128.0.0.0/1)
              # stuck in the routing table — dns-reset-all won't touch them. Checks
              # for the stuck routes and, if found, kickstarts tailscaled + bounces
              # the tunnel to clear them, instead of unplugging Ethernet.
              tail-exit-node-fix = ''
                if test (uname) != Darwin
                  echo "⚠️  macOS-only — try tail-vpn-restart instead."
                  return 1
                end
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

                alias clipboard='pbcopy'
                alias paste='pbpaste'
              '';
            };

            interactiveShellInit = "";
          };
        };
      };
  };
}
