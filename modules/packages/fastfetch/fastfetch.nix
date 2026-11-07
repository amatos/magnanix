# fastfetch system summary (Home Manager), with its config written to
# ~/.config/fastfetch/config.jsonc.
#
# `fastfetch` on PATH is ./fastfetch-wrapper.py, which runs the real binary and
# redraws the section banners (the `custom` modules below) to the width of the
# widest data row. The wrapper still prints something when fastfetch crashes
# or hangs part-way; see the comments at the top of the script. Its tests
# (./test_fastfetch_wrapper.py) run when the package builds.
{
  den.aspects.tui.fastfetch = {
    homeManager =
      { pkgs, ... }:
      let
        inherit (pkgs) fastfetch;

        # The real package (shell completions, licence) with only
        # bin/fastfetch replaced by the wrapper.
        wrapped = pkgs.symlinkJoin {
          name = "fastfetch-wrapped-${fastfetch.version}";
          inherit (fastfetch) version;
          # The join has a single output, so drop the upstream `man` output
          # from outputsToInstall and link the man pages in below instead.
          meta = removeAttrs fastfetch.meta [ "outputsToInstall" ];
          paths = map (o: fastfetch.${o}) fastfetch.outputs;
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            ${pkgs.python3.interpreter} -I ${./test_fastfetch_wrapper.py} ${./fastfetch-wrapper.py}

            rm $out/bin/fastfetch
            install -Dm644 ${./fastfetch-wrapper.py} $out/libexec/fastfetch-wrapper.py
            # --set, not --set-default: an inherited FASTFETCH_BIN=fastfetch
            # would make the wrapper call itself.
            makeWrapper ${pkgs.python3.interpreter} $out/bin/fastfetch \
              --add-flags "-I $out/libexec/fastfetch-wrapper.py" \
              --set FASTFETCH_BIN ${fastfetch}/bin/fastfetch
          '';
        };

        # Section banners. The wrapper resizes them; `{$1}` is the dash run
        # from `display.constants`.
        banner = format: {
          type = "custom";
          inherit format;
        };
        colored = keyColor: type: { inherit type keyColor; };
        green = colored "green";
        yellow = colored "yellow";
        blue = colored "blue";
        magenta = colored "magenta";
      in
      {
        programs.fastfetch = {
          enable = true;
          package = wrapped;

          settings = {
            "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
            logo = {
              type = "builtin";
              height = 15;
              width = 30;
              padding = {
                top = 5;
                left = 3;
              };
            };
            display = {
              separator = "  ";
              constants = [ "─────────────────" ];
              key = {
                type = "icon";
                paddingLeft = 2;
              };
            };
            modules = [
              (banner "┌{$1} {#32}Hardware / Peripherals{#} {$1}┐")
              (green "host")
              (green "cpu")
              (green "gpu")
              (green "disk")
              (green "memory")
              (green "swap")
              (green "display")
              (green "brightness")
              (green "battery")
              (green "poweradapter")
              # `bluetooth` removed — fastfetch 2.63.1's CoreBluetooth probe
              # SIGABRTs on Apple Silicon macOS, killing the rest of the output.
              # Linux side is fine but we drop it cross-platform for simplicity;
              # re-add when upstream ships a fixed release.
              # (green "bluetooth")
              (green "sound")
              {
                type = "command";
                key = "Keyboards";
                keyIcon = "󰌌";
                keyColor = "green";
                text = ''if [[ $(uname) == Linux ]]; then for d in /sys/class/input/event*; do name=$(cat "$d/device/name" 2>/dev/null | sed 's/[[:space:]]*$//'); [ -z "$name" ] && continue; p=$(udevadm info --query=property "$d" 2>/dev/null); echo "$p" | grep -q "^ID_INPUT_KEYBOARD=1" || continue; echo "$p" | grep -q "^ID_INPUT_MOUSE=1" && continue; case "$name" in *" Keyboard"|*" Consumer Control"|*" System Control"|*" Link"|*" Link Keyboard") continue ;; esac; echo "$name"; done | sort -u | paste -sd, - | sed 's/,/, /g'; else echo 'n/a'; fi'';
              }
              {
                type = "command";
                key = "Mice";
                keyIcon = "󰍽";
                keyColor = "green";
                text = ''if [[ $(uname) == Linux ]]; then for d in /sys/class/input/event*; do name=$(cat "$d/device/name" 2>/dev/null | sed 's/[[:space:]]*$//'); [ -z "$name" ] && continue; p=$(udevadm info --query=property "$d" 2>/dev/null); echo "$p" | grep -q "^ID_INPUT_MOUSE=1" || continue; case "$name" in *" Mouse"|*" Consumer Control"|*" Link") continue ;; esac; echo "$name"; done | sort -u | paste -sd, - | sed 's/,/, /g'; else echo 'n/a'; fi'';
              }

              (banner "├{$1} {#33}OS / Software / {#34}Desktop{#} {$1}┤")
              (yellow "os")
              (yellow "kernel")
              (yellow "bios")
              (yellow "packages")
              {
                type = "command";
                key = "Shell";
                keyIcon = "󰞷";
                keyColor = "yellow";
                text = ''name=$(basename "$SHELL"); ver=$("$SHELL" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1); echo "$name''${ver:+ $ver}"'';
              }
              (blue "de")
              (blue "lm")
              (blue "wm")
              (blue "wmtheme")
              (blue "terminal")

              (banner "├{$1} {#35}OS-Age / Uptime / Time{#} {$1}┤")
              {
                type = "command";
                key = "OS Age";
                keyIcon = "󰃨";
                keyColor = "magenta";
                text = "if [[ $(uname) == Darwin ]]; then birth_install=$(stat -f %B /var/db/.AppleSetupDone); else birth_install=$(stat -c %W /); fi; current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days";
              }
              (magenta "uptime")
              (magenta "datetime")

              (banner "├─────────────────────── {#35}Networking{#} ───────────────────────┤")
              {
                type = "localip";
                compact = true;
                keyColor = "magenta";
              }
              # Public IP — commented out for privacy + speed.  Re-enable to show
              # the host's external IP (and city/country via ip-api.com lookup);
              # each fastfetch run then incurs a ~1s network call, and the IP is
              # visible in any screenshot of the output.
              # {
              #   type = "publicip";
              #   timeout = 1000;
              #   keyColor = "magenta";
              # }
              {
                type = "wifi";
                format = "{ssid}";
                keyColor = "magenta";
              }
              (magenta "dns")

              (banner "└──────────────────────────────────────────────────────────┘")
            ];
          };
        };
      };
  };
}
