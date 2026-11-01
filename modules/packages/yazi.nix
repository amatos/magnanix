{
  den.aspects.tui.yazi = {
    # mactag shells out to jdberry/tag, which isn't in nixpkgs.
    darwin.homebrew.brews = [ "tag" ];

    homeManager =
      { pkgs, lib, ... }:
      let
        inherit (pkgs.stdenv.hostPlatform) isDarwin;

        bind = on: run: desc: { inherit on run desc; };

        fetchers =
          name:
          map
            (url: {
              inherit url;
              run = name;
              group = name;
            })
            [
              "*"
              "*/"
            ];
      in
      {
        # Runtime dependencies of the plugins below.
        home.packages = [
          pkgs.imagemagick # convert, zoom
          pkgs.lazygit # lazygit
          pkgs.nushell # sudo
        ]
        # Homebrew isn't on PATH, so expose only the binary mactag needs.
        ++ lib.optionals isDarwin [
          (pkgs.writeShellScriptBin "tag" ''exec /opt/homebrew/bin/tag "$@"'')
        ];

        programs = {
          yazi = {
            enable = true;

            plugins = {
              inherit (pkgs.yaziPlugins)
                chmod
                clipboard
                convert
                diff
                drag
                git
                githead
                lazygit
                starship
                sudo
                zoom
                ;
            }
            # Only packaged for aarch64-darwin.
            // lib.optionalAttrs isDarwin { inherit (pkgs.yaziPlugins) mactag; };

            initLua = ''
              require("starship"):setup()
              require("githead"):setup()
              require("git"):setup()
            ''
            + lib.optionalString isDarwin ''
              require("mactag"):setup {
                keys = {
                  r = "Red",
                  o = "Orange",
                  y = "Yellow",
                  g = "Green",
                  b = "Blue",
                  p = "Purple",
                },
                colors = {
                  Red = "#ee7b70",
                  Orange = "#f5bd5c",
                  Yellow = "#fbe764",
                  Green = "#91fc87",
                  Blue = "#5fa3f8",
                  Purple = "#cb88f8",
                },
                order = 500,
              }
            '';

            settings.plugin.prepend_fetchers = fetchers "git" ++ lib.optionals isDarwin (fetchers "mactag");

            keymap.mgr.prepend_keymap = [
              (bind [ "g" "i" ] "plugin lazygit" "Run lazygit")
              (bind [ "g" "D" ] "plugin diff" "Diff the selected with the hovered file")
              (bind "<C-g>" "plugin drag" "Drag files")

              (bind [ "c" "m" ] "plugin chmod" "Chmod on selected files")
              (bind [ "c" "p" ] "plugin convert -- --extension='png'" "Convert selected files to PNG")
              (bind [ "c" "j" ] "plugin convert -- --extension='jpg'" "Convert selected files to JPG")
              (bind [ "c" "w" ] "plugin convert -- --extension='webp'" "Convert selected files to WebP")

              (bind ">" "plugin zoom 1" "Zoom in hovered file")
              (bind "<" "plugin zoom -1" "Zoom out hovered file")

              (bind "y" [ "yank" "plugin clipboard -- --action=copy" ] "Yank selected files (copy)")
              (bind "x" [ "yank --cut" "plugin clipboard -- --action=copy" ] "Yank selected files (cut)")
              (bind "<C-p>" "plugin clipboard -- --action=paste" "Paste files from the system clipboard")

              (bind [ "R" "p" "p" ] "plugin sudo -- paste" "sudo paste")
              (bind [ "R" "P" ] "plugin sudo -- paste --force" "sudo paste (force)")
              (bind [ "R" "r" ] "plugin sudo -- rename" "sudo rename/bulk-rename")
              (bind [ "R" "p" "l" ] "plugin sudo -- link" "sudo link")
              (bind [ "R" "p" "r" ] "plugin sudo -- link --relative" "sudo link relative path")
              (bind [ "R" "p" "L" ] "plugin sudo -- hardlink" "sudo hardlink")
              (bind [ "R" "a" ] "plugin sudo -- create" "sudo create")
              (bind [ "R" "d" ] "plugin sudo -- remove" "sudo trash")
              (bind [ "R" "D" ] "plugin sudo -- remove --permanently" "sudo delete")
              (bind [ "R" "m" ] "plugin sudo -- chmod" "sudo chmod")
            ]
            ++ lib.optionals isDarwin [
              (bind [ "b" "a" ] "plugin mactag add" "Tag selected files")
              (bind [ "b" "r" ] "plugin mactag remove" "Untag selected files")
            ];
          };
        };
      };
  };
}
