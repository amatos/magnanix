{
  den.aspects.ghostty = {
    # Lets hosts that don't run Ghostty still serve SSH sessions coming from it.
    terminfo = {
      nixos = { pkgs, ... }: {
        environment.systemPackages = [ pkgs.ghostty.terminfo ];
      };

      darwin = { pkgs, ... }: {
        environment.systemPackages = [ pkgs.ghostty-bin.terminfo ];
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
        # Users who own Dracula PRO opt in with `magnanix.draculaPro` (see
        # modules/den/dracula-pro.nix); everyone else gets Ghostty's built-in Dracula.
        # Each PRO variant is symlinked out of the store into
        # ~/.config/ghostty/themes as `dracula-pro-<variant>`; `pro` is the
        # flagship dark theme and is linked as plain `dracula-pro`.
        draculaPro = config.magnanix.draculaPro;
        draculaProThemes = "${draculaPro.dir}/themes/ghostty";
        draculaProVariants = [
          "pro"
          "alucard"
          "blade"
          "buffy"
          "lincoln"
          "morbius"
          "nosferatu"
          "van-helsing"
        ];
        themeName = variant: if variant == "pro" then "dracula-pro" else "dracula-pro-${variant}";
      in
      {
        programs.ghostty = {
          enable = true;
          # The `ghostty` package doesn't build on macOS; `ghostty-bin` is the upstream app bundle.
          package = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;

          # Written to ~/.config/ghostty/config and checked with
          # `ghostty +validate-config` whenever it changes.
          settings = {
            # Follows the system appearance, like Zed's Dracula/Alucard pairing.
            theme =
              if draculaPro.enable then "light:${themeName "alucard"},dark:${themeName "pro"}" else "Dracula";

            # Ghostty's default is 13.
            font-size = 14;

            # Added to Ghostty's defaults (listed features are toggled, the rest
            # keep their defaults). `sudo` keeps Ghostty's terminfo under sudo;
            # `ssh-terminfo` installs it on remote hosts on first connect, for
            # machines outside magnanix that lack the `terminfo` part above;
            # `ssh-env` falls back to TERM=xterm-256color where that's impossible.
            shell-integration-features = "sudo,ssh-env,ssh-terminfo";
          };
        };

        # Lets modules/den/dracula-pro.nix clone the checkout on this host.
        magnanix.draculaPro.usedBy = lib.mkIf draculaPro.enable [ "ghostty" ];

        xdg.configFile = lib.mkIf draculaPro.enable (
          {
            # Until the checkout exists (e.g. its clone failed on a fresh host),
            # validation would reject the PRO theme names and abort the switch.
            # Skip it then; Ghostty falls back to its default colors.
            "ghostty/config".onChange = lib.mkForce ''
              if [[ -d ${lib.escapeShellArg draculaProThemes} ]]; then
                ${lib.getExe config.programs.ghostty.package} +validate-config --config-file=${config.xdg.configHome}/ghostty/config
              else
                warnEcho ${lib.escapeShellArg "Skipping Ghostty config validation: ${draculaProThemes} is missing."}
              fi
            '';
          }
          // lib.listToAttrs (
            map (
              variant:
              lib.nameValuePair "ghostty/themes/${themeName variant}" {
                source = config.lib.file.mkOutOfStoreSymlink "${draculaProThemes}/${variant}";
              }
            ) draculaProVariants
          )
        );
      };
  };
}
