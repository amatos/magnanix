# Aspect:    den.aspects.macos.automounterHelper
# Platforms: darwin, home-manager (macOS only; does nothing on Linux)
# Purpose:   AutoMounter Helper, the companion to AutoMounter that mounts
#            network shares at custom locations: the Homebrew cask, plus the
#            per-user install its own installer would do.
#
# Notes:
# - The cask is `installer manual`: brew only stages AutoMounterHelper.app in
#   the Caskroom. Clicking Install in that app copies it to
#   ~/Library/AutoMounterHelper, removes its quarantine, registers it with
#   Launch Services and writes a LaunchAgent. Home Manager does the same here,
#   so nothing has to be opened by hand, including after a cask upgrade.
# - Home Manager activation runs after `brew bundle`, so the Caskroom copy is
#   already there on the switch that adds the cask.
# - The LaunchAgent is the one the installer writes (same keys and values) (1.10.1), so
#   activation writes it itself rather than with launchd.agents, which would
#   wrap the program in `/bin/sh -c wait4path`. Don't click Uninstall in the
#   app; remove the aspect, and the cask's uninstall unloads and deletes the
#   agent and moves ~/Library/AutoMounterHelper to the Trash.
# - The licence agreement the installer shows is skipped.
{
  den.aspects.macos.automounterHelper = {
    darwin.homebrew.casks = [ "automounterhelper" ];

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        label = "nz.co.pixeleyes.AutoMounterHelper";
        caskroom = "/opt/homebrew/Caskroom/automounterhelper";
        installDir = "${config.home.homeDirectory}/Library/AutoMounterHelper";
        app = "${installDir}/AutoMounterHelper.app";

        # The LaunchAgent AutoMounterHelper.app's installer writes.
        agent = pkgs.writeText "${label}.plist" (
          lib.generators.toPlist { escape = true; } {
            Label = label;
            ProgramArguments = [ "${app}/Contents/MacOS/AutoMounterHelper" ];
            AssociatedBundleIdentifiers = [ label ];
            KeepAlive.SuccessfulExit = false;
            LimitLoadToSessionType = "Aqua";
          }
        );
        agentPath = "${config.home.homeDirectory}/Library/LaunchAgents/${label}.plist";

        # Copies the newest Caskroom AutoMounterHelper.app to $app when its
        # build differs from the installed one, writes the LaunchAgent when it
        # differs, and (re)loads the agent if either changed or it isn't
        # loaded. Warns and does nothing if the cask isn't installed yet.
        install = pkgs.writeShellApplication {
          name = "automounter-helper-install";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.diffutils
            pkgs.findutils
          ];
          text = ''
            caskroom=$1
            app=$2
            label=$3
            agent=$4
            agentPath=$5
            domain="gui/$(id -u)"
            changed=

            buildOf() {
              /usr/bin/plutil -extract CFBundleVersion raw -o - "$1/Contents/Info.plist" 2>/dev/null || true
            }

            source=$(find "$caskroom" -mindepth 2 -maxdepth 2 -name AutoMounterHelper.app 2>/dev/null \
              | sort -V | tail -n 1)
            if [[ -z $source ]]; then
              echo "AutoMounter Helper: no AutoMounterHelper.app in $caskroom; switch again after brew installs the cask" >&2
              exit 0
            fi

            if [[ ! -d $app || $(buildOf "$source") != "$(buildOf "$app")" ]]; then
              echo "Installing AutoMounter Helper $(buildOf "$source") from $source"
              mkdir -p "$(dirname "$app")"
              rm -rf "$app"
              /usr/bin/ditto "$source" "$app"
              /usr/bin/xattr -dr com.apple.quarantine "$app" 2>/dev/null || true
              /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
                -f "$app" || echo "AutoMounter Helper: Launch Services registration failed" >&2
              changed=1
            fi

            if ! cmp -s "$agent" "$agentPath"; then
              mkdir -p "$(dirname "$agentPath")"
              install -m 644 "$agent" "$agentPath"
              changed=1
            fi

            if /bin/launchctl print "$domain/$label" >/dev/null 2>&1; then
              [[ -z $changed ]] && exit 0
              /bin/launchctl bootout "$domain/$label" 2>/dev/null || true
            fi
            # bootstrap can fail briefly right after a bootout
            for _ in 1 2 3 4 5; do
              /bin/launchctl bootstrap "$domain" "$agentPath" 2>/dev/null && exit 0
              sleep 1
            done
            echo "AutoMounter Helper: couldn't load $agentPath" >&2
          '';
        };
      in
      lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        home.activation.automounterHelper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [[ -v DRY_RUN ]]; then
            echo ${lib.escapeShellArg "Would install AutoMounter Helper from ${caskroom} to ${app}"}
          else
            run ${lib.getExe install} ${
              lib.escapeShellArgs [
                caskroom
                app
                label
                agent
                agentPath
              ]
            }
          fi
        '';
      };
  };
}
