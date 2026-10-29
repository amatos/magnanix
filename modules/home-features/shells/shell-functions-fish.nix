{
  den.aspects.shell.fishFunctions = {
    homeManager =
      { pkgs, config, ... }:
      let
        commonFunctions = {
          # ── GPG / smartcard / YubiKey ──────────────────────────────────────────
          reload-gpg-agent = ''
            echo "🔁 Reloading GPG agent..."
            gpg-connect-agent reloadagent /bye
            and echo "✅ GPG agent reloaded."
          '';

          reload-yubikey = ''
            echo "🔄 Relearning YubiKey smartcard..."
            gpg-connect-agent "scd serialno" "learn --force" /bye
            and echo "✅ YubiKey smartcard reloaded."
          '';

          reload-pcsd = ''
            echo "🔁 Restarting smartcard daemon (pcscd)..."
            if test (uname) = Darwin
              sudo launchctl kickstart -k system/com.apple.pcscd
            else
              sudo systemctl restart pcscd.service
            end
            and echo "✅ pcscd restarted."
          '';
          yubikey-reset = ''
            echo "🔐 Starting full YubiKey + GPG reset..."

            echo
            echo "🔁 Restarting smartcard services..."
            if test (uname) = Darwin
              sudo launchctl kickstart -k system/com.apple.pcscd
            else
              sudo systemctl restart pcscd.service
              sudo systemctl restart pcscd.socket
            end

            echo
            echo "🔁 Reloading GPG agent..."
            reload-gpg-agent

            echo
            echo "🔄 Refreshing YubiKey smartcard..."
            reload-yubikey

            echo
            echo "📇 Checking GPG smartcard status..."
            gpg --card-status; or echo "⚠️  Unable to read card status."

            echo
            echo "🧮 Getting PIN retry counters..."
            gpg-connect-agent 'scd getinfo retry_counter' /bye 2>/dev/null
            or echo "⚠️  Could not fetch retry counters."

            echo
            echo "🔍 Checking SSH agent socket and identities..."
            if set -q SSH_AUTH_SOCK
              echo "📡 SSH agent socket detected at: $SSH_AUTH_SOCK"
              ssh-add -L; or echo "⚠️  No SSH keys loaded via agent."
            else
              echo "❌ SSH agent socket not found."
            end

            echo
            echo "✅ YubiKey and related services reset complete."
          '';
          ssh-load-yubikey = ''
            gpg-connect-agent updatestartuptty /bye
            and ssh-add -L
          '';
          # ── Docker control ─────────────────────────────────────────────────────
          docker-stop-containers = ''
            echo "🛑 Stopping all running containers..."
            docker ps -q | xargs -r docker stop
            and echo "✅ All containers stopped."
          '';

          docker-pause-containers = ''
            echo "⏸️ Pausing all running containers..."
            docker ps -q | xargs -r docker pause
            and echo "✅ All containers paused."
          '';

          docker-remove-containers = ''
            echo "🧼 Removing all stopped containers..."
            docker ps -a -q | xargs -r docker rm
            and echo "✅ Stopped containers removed."
          '';

          docker-delete-images = ''
            echo "🧹 Deleting all Docker images..."
            docker images -q | xargs -r docker rmi
            and echo "✅ All images removed."
          '';

          docker-delete-volumes = ''
            echo "🗑️ Removing dangling volumes..."
            docker volume ls -qf dangling=true | xargs -r docker volume rm
            and echo "✅ Dangling volumes removed."
          '';

          docker-delete-all = ''
            echo "🔥 Stopping all containers and pruning system..."
            docker ps -q | xargs -r docker stop
            docker system prune -a --volumes -f
            and echo "✅ Docker system fully cleaned."
          '';

          docker-delete-app = ''
            if test (count $argv) -eq 0
              echo "⚠️  Usage: docker-delete-app <name>"
              return 1
            end
            echo "🗑️ Searching for containers matching \"$argv[1]\"..."
            for id in (docker ps -a | grep $argv[1] | awk '{print $1}')
              echo "➤ Removing container: $id"
              docker rm $id
            end
            echo "✅ Matching containers removed."
          '';

          # ── Tailscale ──────────────────────────────────────────────────────────
          tail-vpn-restart = ''
            echo "🔄 Restarting Tailscale..."
            if tailscale status >/dev/null 2>&1
              echo "⬇️ Stopping Tailscale..."
              sudo tailscale down
            else
              echo "ℹ️ Tailscale already down."
            end
            echo "⬆️ Starting Tailscale..."
            sudo tailscale up
            echo
            echo "📡 Current Tailscale status:"
            sudo tailscale status
            if test (count $argv) -gt 0
              echo
              echo "🔎 DNS check for: $argv[1]"
              nslookup $argv[1]; or echo "❌ DNS lookup failed for $argv[1]"
            end
            echo "✅ Tailscale restart complete."
          '';

          current-exit-node = ''
            echo "📍 Current exit node info:"
            tailscale status | grep (tailscale ip -4)
            tailscale status --json | jq '.ExitNodeIP'
          '';

          use-exit-node = ''
            echo "🌐 Scanning for available exit nodes..."
            set -l reset_line "RESET   🔄   [Disable Exit Node]"
            set -l choices (tailscale status \
              | grep -i 'offers exit node' \
              | grep -vi 'offline' \
              | awk '{ip=$1; host=$2; status=""; for(i=5;i<=NF;++i){status=status" "$i}; print ip "|" host "|" status}' \
              | column -t -s '|')
            set -a choices "$reset_line"
            set -l selected (printf "%s\n" $choices | fzf \
              --prompt="🔘 Select an exit node (or reset): " \
              --header="IP Address        Hostname               Status" \
              --height=30% --reverse --ansi)
            if test -z "$selected"
              echo "❌ Cancelled or no selection made."
              return 1
            end
            if test "$selected" = "$reset_line"
              echo "🚫 Disabling exit node..."
              tailscale set --exit-node=
              echo "✅ Exit node disabled."
              return 0
            end
            set -l ip (echo $selected | awk '{print $1}')
            echo "🚀 Switching to exit node: $ip"
            tailscale set --exit-node=$ip
            and echo "✅ Now using exit node: $ip"
          '';

          # Generic Tailscale control menu — reports state, dispatches to the common
          # toggles. Exit-node management reuses use-exit-node (picker + reset).
          use-tailscale = ''
            set -l jq_exit 'if (.ExitNodeStatus.ID // "") == "" then "none" else (.ExitNodeStatus.ID) as $id | (([ .Peer // {} | to_entries[] | select(.value.ID == $id) | .value.HostName ][0]) // (.ExitNodeStatus.TailscaleIPs[0] | sub("/.*"; ""))) end'
            set -l exit_node (tailscale status --json 2>/dev/null | jq -r "$jq_exit")
            test -z "$exit_node"; and set exit_node "none"
            set -l routes "off"
            if test (tailscale debug prefs 2>/dev/null | jq -r '.RouteAll') = "true"
              set routes "on"
            end
            set -l action (printf "%s\n" \
              "🌐 Exit node        (active: $exit_node)" \
              "🛣  Accept routes     (currently: $routes)" \
              | fzf --prompt="🔧 use-tailscale ▸ " \
                --header="Select a Tailscale setting to manage" \
                --height=20% --reverse --ansi)
            switch "$action"
              case '*Exit node*'
                use-exit-node
              case '*Accept routes*'
                if test "$routes" = "on"
                  echo "🚫 Disabling accept-routes (subnet routes)..."
                  tailscale set --accept-routes=false; and echo "✅ accept-routes is now OFF"
                else
                  echo "✅ Enabling accept-routes (subnet routes)..."
                  tailscale set --accept-routes=true; and echo "✅ accept-routes is now ON"
                end
              case '*'
                echo "❌ Cancelled or no selection made."
                return 1
            end
          '';

          # ── DNS / network ──────────────────────────────────────────────────────
          tail-fix-dns = ''
            echo "🔧 Restarting DNS services (Tailscale-related)..."
            if test (uname) = Darwin
              sudo dscacheutil -flushcache
              sudo killall -HUP mDNSResponder
              echo "✅ macOS DNS cache flushed."
            else
              if systemctl is-active systemd-resolved >/dev/null 2>&1
                sudo systemctl restart systemd-resolved; and echo "✅ systemd-resolved restarted."
              else
                echo "⚠️ systemd-resolved not active."
              end
              if systemctl is-active NetworkManager >/dev/null 2>&1
                sudo systemctl restart NetworkManager; and echo "✅ NetworkManager restarted."
              else
                echo "⚠️ NetworkManager not active."
              end
              if systemctl is-active tailscaled >/dev/null 2>&1
                sudo systemctl restart tailscaled; and echo "✅ tailscaled restarted."
              else
                echo "⚠️ tailscaled not active."
              end
            end
            echo "✅ DNS services refreshed."
          '';

          dns-reset-all = ''
            echo "🔁 Restarting all DNS-related services..."
            if test (uname) = Darwin
              sudo dscacheutil -flushcache
              sudo killall -HUP mDNSResponder
              echo "✅ macOS DNS cache flushed."
            else
              sudo systemctl restart systemd-resolved; and echo "✅ systemd-resolved restarted."
              sudo systemctl restart NetworkManager; and echo "✅ NetworkManager restarted."
              sudo systemctl restart tailscaled; and echo "✅ tailscaled restarted."
              sudo systemctl restart resolvconf; and echo "✅ resolvconf restarted."
            end
            echo "✅ All DNS components reset."
          '';

          # ── Network info (mynet dispatcher + helpers) ─────────────────────────
          _mynet_ip = ''
            set -l GRN (set_color green)
            set -l CYN (set_color cyan)
            set -l NC  (set_color normal)
            echo "$GRN""Local Network IPs""$NC"
            if test (uname) = Darwin
              echo "$GRN""Interfaces:""$NC"
              ifconfig | awk -v c="\033[0;36m" -v n="\033[0m" \
                '/^[a-z]/{gsub(/:$/,"",$1); state=($2 ~ /UP/)?"UP":"DOWN"; printf "   - %s%-18s%s  %s\n", c, $1, n, state}'
              echo "$GRN""IPv4 Addresses:""$NC"
              ifconfig | awk -v c="\033[0;36m" -v n="\033[0m" \
                '/^[a-z]/{gsub(/:$/,"",$1); iface=$1} /inet /{printf "   - %s%-18s%s  %s\n", c, iface, n, $2}'
              echo "$GRN""IPv6 Addresses:""$NC"
              ifconfig | awk -v c="\033[0;36m" -v n="\033[0m" \
                '/^[a-z]/{gsub(/:$/,"",$1); iface=$1} /inet6/{printf "   - %s%-18s%s  %s\n", c, iface, n, $2}'
            else
              echo "$GRN""Interfaces:""$NC"
              ip -br link show | awk -v c="\033[0;36m" -v n="\033[0m" \
                '{sub(/@.*/,"",$1); printf "   - %s%-18s%s  %s\n", c, $1, n, $2}'
              echo "$GRN""IPv4 Addresses:""$NC"
              ip -4 -o addr show | awk -v c="\033[0;36m" -v n="\033[0m" \
                '{split($4,a,"/"); printf "   - %s%-18s%s  %s\n", c, $2, n, a[1]}'
              echo "$GRN""IPv6 Addresses:""$NC"
              ip -6 -o addr show | awk -v c="\033[0;36m" -v n="\033[0m" \
                '{split($4,a,"/"); printf "   - %s%-18s%s  %s\n", c, $2, n, a[1]}'
            end
            echo "$GRN""Public IPs (via multiple sources):""$NC"
            dig +short whoami.akamai.net @ns1-1.akamaitech.net | awk -v c="\033[0;36m" -v n="\033[0m" '{printf "   %sAkamai%s      : %s\n", c, n, $1}'
            curl -s ifconfig.me/ip | cut -f1 -d"%" | awk -v c="\033[0;36m" -v n="\033[0m" '{printf "   %sifconfig.me%s : %s\n", c, n, $1}'
            echo "$GRN""Tailscale Info:""$NC"
            if type -q tailscale
              tailscale ip -4 2>/dev/null | awk -v c="\033[0;36m" -v n="\033[0m" '{printf "   %sIP:%s      %s\n", c, n, $1}'
              set -l _tsdomain (tailscale status 2>/dev/null | head -1 | awk '{sub(/^[^.]+\./, "", $3); print $3}')
              test -n "$_tsdomain"; and printf "   %sTailnet:%s %s\n" $CYN $NC $_tsdomain
              set -l _tsemail (tailscale status --json 2>/dev/null | jq -r '.CurrentTailnet.Name // empty')
              test -n "$_tsemail"; and printf "   %sEmail:%s   %s\n" $CYN $NC $_tsemail
            else
              set -l YLW (set_color yellow)
              printf "   %s(not installed)%s\n" $YLW $NC
            end
          '';

          _mynet_info = ''
            set -l CYN (set_color cyan)
            set -l GRN (set_color green)
            set -l YLW (set_color yellow)
            set -l NC  (set_color normal)
            echo "$GRN""Fetching extended network info via ipwho.is...""$NC"
            set -l data (curl -s http://ipwho.is/)
            if test -z "$data"
              printf "  %sCould not reach ipwho.is%s\n" $YLW $NC
              return 1
            end
            for field in ip type country region city 'timezone.id' 'timezone.utc' 'timezone.current_time' 'connection.isp'
              set -l label $field
              switch $field
                case ip;                        set label "IP"
                case type;                      set label "IP Type"
                case country;                   set label "Country"
                case region;                    set label "Region"
                case city;                      set label "City"
                case 'timezone.id';             set label "Timezone"
                case 'timezone.utc';            set label "UTC Offset"
                case 'timezone.current_time';   set label "Local Time"
                case 'connection.isp';          set label "ISP"
              end
              set -l val (printf '%s' $data | jq -r ".$field // \"n/a\"")
              printf "  %s%-14s%s %s\n" $CYN $label $NC $val
            end
          '';

          _mynet_table = ''
            set -l CYN (set_color cyan)
            set -l GRN (set_color green)
            set -l YLW (set_color yellow)
            set -l DIM (set_color --dim)
            set -l NC  (set_color normal)
            echo "$GRN""Getting your current public IP...""$NC"
            set -l ip (curl -s https://ifconfig.me)
            if test -z "$ip"
              printf "%sCould not retrieve IP.%s\n" $YLW $NC
              return 1
            end
            printf "%sLooking up details using ipwho.is...%s\n" $DIM $NC
            set -l ipwho_data (curl -s "https://ipwho.is/")
            set -l country (printf '%s' $ipwho_data | jq -r '.country')
            set -l isp (printf '%s' $ipwho_data | jq -r '.connection.isp' | awk '{print $1}')
            test -z "$country"; or test "$country" = "null"; and set country "Unknown"
            test -z "$isp";     or test "$isp" = "null";     and set isp "Unknown"
            echo
            echo "$GRN""Current IP Info:""$NC"
            printf "   %s%-18s %-20s %s%s\n" $CYN "IP Address" "Country" "Provider" $NC
            printf "   %-18s %-20s %s\n" $ip $country $isp
            echo
            echo "$GRN""Full IP List:""$NC"
            printf "%s%-26s %-16s %s%s\n" $CYN "IP Address" "Country" "Provider" $NC
            printf "%s\t%s\t%s\n" $ip $country $isp | column -t -s \t
          '';

          mynet = ''
            set -l subcmd ip
            if test (count $argv) -gt 0
              set subcmd $argv[1]
            else
              set subcmd all
            end
            switch $subcmd
              case ip;    _mynet_ip
              case info;  _mynet_info
              case table; _mynet_table
              case all
                _mynet_ip
                echo
                _mynet_info
                echo
                _mynet_table
              case '*'
                echo "Usage: mynet [ip|info|table]"
                echo "  ip    — local, public, and Tailscale IPs"
                echo "  info  — geo/ISP lookup via ipwho.is"
                echo "  table — formatted table with static entries"
                echo "  (no arg) — run all three"
                return 1
            end
          '';

          myping = ''
            if test (count $argv) -eq 0
              echo "Usage: myping <host> [ping args...]"
              return 1
            end
            ping $argv | while read -l line
              printf "[%s] %s\n" (date '+%H:%M:%S') "$line"
            end
          '';
          # ── zoxide + fzf navigation ────────────────────────────────────────────
          zox = ''
            echo "📂 Choose a recent directory to jump into:"
            set -l dir (zoxide query -l | fzf --preview="ls -lh --color=always {} 2>/dev/null" --preview-window=up:30%)
            if test -n "$dir"
              echo "🚀 Jumping to: $dir"
              cd $dir; or echo "❌ Failed to cd into $dir"
            else
              echo "❌ No directory selected."
            end
          '';
        };
      in
      {
        programs.fish.functions = commonFunctions;
      };
  };
}
