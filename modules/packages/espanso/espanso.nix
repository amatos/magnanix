# Aspects:   den.aspects.espanso         (the text expander, per host)
#            den.aspects.espanso.secure  (opt-in, per user per host)
# Platforms: espanso: home-manager, nixos; secure: home-manager
# Purpose:   Espanso, a cross-platform text expander, run at login (launchd on
#            macOS, a systemd user service on Linux), with matches from three
#            places:
#            - public:   services.espanso.matches below (match/base.yml)
#            - personal: a private git repo checked out at
#                        magnanix.espanso.dir (cloned on activation from
#                        magnanix.espanso.repo) and linked as match/personal
#            - secure:   sops-encrypted secrets/users/<user>-espanso-<name>.yaml,
#                        each decrypted to match/<name>.yml (espanso.secure)
#
# Notes:
# - Espanso loads every *.yml/*.yaml under match/, recursively, except names
#   starting with `_`, following symlinks. So the personal repo must hold only
#   match files (no CI YAML). Espanso's file watcher doesn't see changes behind
#   the symlink, so run `espanso restart` after editing the checkout.
# - The personal clone is best-effort, like Dracula PRO's: it runs only when
#   the directory is missing, never pulls, and only warns when credentials are
#   unavailable (no SSH agent, or Home Manager's systemd unit on NixOS).
# - Edit a secure file with `sops secrets/users/<user>-espanso-<name>.yaml`;
#   new files are picked up by name, no Nix change needed. Only machines whose
#   user age key is a recipient (see .sops.yaml) can include `secure`. Run
#   `espanso restart` after a switch that changes one: the symlink target
#   moves, which Espanso doesn't always notice.
# - macOS: Espanso needs Accessibility permission. The binary lives in the Nix
#   store, so macOS may ask again after an update changes its path.
# - Linux: a wrapper picks the X11 or Wayland build from $WAYLAND_DISPLAY. The
#   Wayland build reads /dev/input (`input` group) and types through
#   /dev/uinput (`uinput` group), so every user on the host gets both.
# - The search bar's shortcut (Alt+Space, Option+Space on macOS) is off.
{ lib, ... }:
{
  # Options for every user, so a user aspect can set its repo once even on hosts
  # without Espanso; the clone only happens where services.espanso is enabled.
  den.default.homeManager =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.magnanix.espanso;
    in
    {
      options.magnanix.espanso = {
        repo = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "git@github.com:someone/espanso-matches.git";
          description = ''
            Private git repo of everyday Espanso matches, cloned into `dir` during
            activation when `dir` doesn't exist. Must not embed credentials.
            `null` leaves `dir` to the user (it is linked either way).
          '';
        };

        dir = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/src/espanso-matches";
          defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/src/espanso-matches"'';
          description = "Absolute path of the personal matches checkout, linked into Espanso's match directory as `personal`.";
        };
      };

      # A link to the checkout, so it can live wherever the user keeps repos.
      # Dangling until the clone below (or the user) creates `dir`.
      config.xdg.configFile."espanso/match/personal" = lib.mkIf config.services.espanso.enable {
        source = config.lib.file.mkOutOfStoreSymlink cfg.dir;
      };

      config.home.activation.espansoPersonalClone =
        lib.mkIf (config.services.espanso.enable && cfg.repo != null)
          (
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              if [[ ! -e ${lib.escapeShellArg cfg.dir} ]]; then
                if ! run env GIT_TERMINAL_PROMPT=0 \
                    GIT_SSH_COMMAND=${lib.escapeShellArg "${pkgs.openssh}/bin/ssh -o BatchMode=yes"} \
                    ${lib.getExe pkgs.git} clone --quiet ${
                      lib.escapeShellArgs [
                        cfg.repo
                        cfg.dir
                      ]
                    }; then
                  warnEcho ${lib.escapeShellArg "Could not clone the personal Espanso matches; run: git clone ${cfg.repo} ${cfg.dir}"}
                fi
              fi
            ''
          );
    };

  den.aspects.espanso = {
    homeManager = {
      services.espanso = {
        enable = true;

        # No search bar shortcut (default Alt+Space / Option+Space).
        configs.default.search_shortcut = "off";

        # Public, shareable matches only. Everyday personal ones go in the
        # personal repo; sensitive ones in `secure`.
        matches.base.matches = [
          {
            trigger = ":date";
            replace = "{{today}}";
            vars = [
              {
                name = "today";
                type = "date";
                params.format = "%Y-%m-%d";
              }
            ];
          }
        ];
      };
    };

    nixos.hardware.uinput.enable = true;

    includes = [
      (
        { host, ... }:
        {
          nixos.users.users = lib.genAttrs (lib.attrNames host.users) (_: {
            extraGroups = [
              "input"
              "uinput"
            ];
          });
        }
      )
    ];

    # A user's sops-encrypted matches: every secrets/users/<user>-espanso-<name>.yaml,
    # decrypted whole to match/<name>.yml. Include from
    # `den.aspects.<host>.provides.<user>` on hosts that also include `espanso` and
    # where the user's age key can decrypt those files.
    secure.includes = [
      (
        { user, ... }:
        let
          secretsDir = ../../../secrets/users;
          prefix = "${user.userName}-espanso-";
          names = lib.pipe (builtins.readDir secretsDir) [
            (lib.filterAttrs (
              file: type: type == "regular" && lib.hasPrefix prefix file && lib.hasSuffix ".yaml" file
            ))
            lib.attrNames
            (map (file: lib.removeSuffix ".yaml" (lib.removePrefix prefix file)))
          ];
        in
        {
          homeManager =
            { config, ... }:
            {
              sops.secrets = lib.genAttrs' names (
                name:
                # The name ends in .yml because Espanso resolves the symlink and
                # rejects match files without an extension.
                lib.nameValuePair "espanso-${name}.yml" {
                  sopsFile = secretsDir + "/${prefix}${name}.yaml";
                  format = "yaml";
                  key = ""; # the whole file
                  path = "${config.xdg.configHome}/espanso/match/${name}.yml";
                }
              );
            };
        }
      )
    ];
  };
}
