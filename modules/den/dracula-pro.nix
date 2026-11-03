{
  # Dracula PRO (https://draculatheme.com/pro) is a paid theme pack under a
  # personal, non-transferable license, so its files never enter this public
  # repo or the Nix store (where a binary cache could push them). Users who own
  # it opt in here, once; app modules then link themes straight out of `dir`
  # and register themselves in `usedBy`.
  #
  # When `repo` is set, `dir` is missing and some app on this host uses the
  # themes, activation clones it with the user's own git credentials. Hosts with
  # no such app (e.g. a headless server) never try. Nothing here grants access:
  # anyone else running this config (a fork, another user) is refused by GitHub.
  den.default.homeManager =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.magnanix.draculaPro;
    in
    {
      options.magnanix.draculaPro = {
        enable = lib.mkEnableOption "Dracula PRO themes (from a local checkout of the licensed theme pack) in apps that support them";

        dir = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/src/dracula-pro";
          defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/src/dracula-pro"'';
          description = "Absolute path of the local Dracula PRO checkout.";
        };

        repo = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "git@github.com:dracula-pro/dracula-pro.git";
          description = ''
            Git URL cloned into `dir` during activation when `dir` doesn't exist.
            Must not embed credentials: the clone authenticates as whoever runs
            it. `null` leaves `dir` entirely to the user.
          '';
        };

        usedBy = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          internal = true;
          description = "Apps on this host using the Dracula PRO themes; set by their modules. Empty means no clone.";
        };
      };

      # Before onFilesChange, so apps validating their config on change (Ghostty)
      # already see the themes. Non-interactive and non-fatal: without working
      # credentials (no SSH agent yet on a fresh host, or a Home Manager systemd
      # unit on NixOS) it warns and the switch carries on.
      config.home.activation.draculaProClone =
        lib.mkIf (cfg.enable && cfg.repo != null && cfg.usedBy != [ ])
          (
            lib.hm.dag.entryBetween [ "onFilesChange" ] [ "writeBoundary" ] ''
              if [[ ! -e ${lib.escapeShellArg cfg.dir} ]]; then
                if ! run env GIT_TERMINAL_PROMPT=0 \
                    GIT_SSH_COMMAND=${lib.escapeShellArg "${pkgs.openssh}/bin/ssh -o BatchMode=yes"} \
                    ${lib.getExe pkgs.git} clone --quiet ${
                      lib.escapeShellArgs [
                        cfg.repo
                        cfg.dir
                      ]
                    }; then
                  warnEcho ${lib.escapeShellArg "Could not clone Dracula PRO (used by ${lib.concatStringsSep ", " cfg.usedBy}); its themes stay unavailable until you run: git clone ${cfg.repo} ${cfg.dir}"}
                fi
              fi
            ''
          );
    };
}
