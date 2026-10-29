{
  den.aspects.zed = {
    darwin.homebrew.casks = [
      "zed"
      "zed-delta"
    ];

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;

        # Zed's settings.json is tracked in this repo and symlinked into place, so
        # Zed can write to it and every change shows up as a normal git diff.
        repoDir = "${config.home.homeDirectory}/Projects/magnanix";
        settingsFile = "${repoDir}/modules/home-features/zed/settings.json";

        # Skeleton: defaults merged *under* the tracked file on every switch. Keys
        # already in the file win, so changes made in Zed stick; keys missing from
        # the file are filled in from here. Objects merge recursively; arrays are
        # replaced as a whole by the file's value.
        #
        # Keep this machine-independent: whatever is listed here is written into
        # the tracked file, so no /nix/store paths or host-specific values.
        defaultSettings = {
          # ── Identity / look ──────────────────────────────────────────────
          base_keymap = "Zed";

          # Follow the system appearance. Names must match an installed theme
          # exactly (built-in, or from an extension in auto_install_extensions).
          theme = {
            mode = "system";
            light = "Dracula Light (Alucard";
            dark = "Dracula Solid";
          };
          icon_theme = {
            mode = "system";
            light = "Colored Zed Icons Theme Light";
            dark = "Colored Zed Icons Theme Dark";
          };
          ui_font_size = 16;
          buffer_font_size = 15;
          buffer_font_family = ".ZedMono";

          # Extensions Zed installs on startup, by ID (https://zed.dev/extensions).
          auto_install_extensions = {
            nix = true;
            dracula = true;
            colored-zed-icons-theme = true;
          };

          # ── Editor behaviour ─────────────────────────────────────────────
          tab_size = 2;
          soft_wrap = "editor_width";
          show_whitespaces = "selection";
          preferred_line_length = 100;
          remove_trailing_whitespace_on_save = true;
          ensure_final_newline_on_save = true;
          autosave = {
            after_delay = {
              milliseconds = 1000;
            };
          };
          auto_indent = "syntax_aware";
          format_on_save = "on";
          confirm_quit = false;

          # ── Git ──────────────────────────────────────────────────────────
          git = {
            inline_blame = {
              enabled = true;
            };
          };

          # ── Terminal ─────────────────────────────────────────────────────
          terminal = {
            font_family = "JetBrainsMono Nerd Font";
            font_size = 13;
            copy_on_select = true;
            shell = {
              program = "fish";
            };
          };

          # ── Chrome ───────────────────────────────────────────────────────
          tabs = {
            file_icons = true;
            git_status = true;
          }
          // lib.optionalAttrs isDarwin {
            close_position = "left";
          };

          scrollbar = {
            show = "auto";
          };
          indent_guides = {
            enabled = true;
          };

          # ── LSP: nil (Nix) ───────────────────────────────────────────────
          # The Zed "Nix" extension ships both `nil` and `nixd` and defaults to
          # `nixd`. Select `nil` and disable `nixd` so the extension stops demanding it.
          languages = {
            Nix = {
              language_servers = [
                "nil"
                "!nixd"
              ];
            };
          };

          # Pin nil's flake handling so it stops popping "Some flake inputs are
          # not available — fetch them now?". autoArchive = false keeps nil from
          # running `nix flake archive` in the background; flip both to true if
          # you want full cross-input evaluation/completion (heavier on a flake
          # this size).
          lsp = {
            nil = {
              initialization_options = {
                nix = {
                  flake = {
                    autoArchive = false;
                    autoEvalInputs = false;
                  };
                };
              };
            };
          };
        };

        # Same JSON5 reader Home Manager's zed-editor module uses; Zed's
        # settings.json allows comments.
        json5 = pkgs.python3Packages.toPythonApplication pkgs.python3Packages.json5;

        # Files to open with Zed. macOS (duti) associates by extension; Linux
        # (xdg.mimeApps) associates by MIME type.
        associations = [
          {
            ext = ".txt";
            mime = "text/plain";
          }
          {
            ext = ".md";
            mime = "text/markdown";
          }
          {
            ext = ".nix";
            mime = "text/x-nix";
          }
          {
            ext = ".yaml";
            mime = "application/yaml";
          }
          {
            ext = ".asc";
            mime = "application/pgp-keys";
          }
          {
            ext = ".sh";
            mime = "application/x-shellscript";
          }
        ];
      in
      {
        # duti is macOS-only; on Linux Zed comes from nixpkgs (no cask there).
        home.packages = lib.optionals isDarwin [ pkgs.duti ] ++ lib.optionals isLinux [ pkgs.zed-editor ];

        xdg.configFile."zed/settings.json".source = config.lib.file.mkOutOfStoreSymlink settingsFile;

        # Runs after the symlink exists. Creates the tracked file from the skeleton
        # if it's missing; otherwise fills in missing keys (file wins on conflicts).
        home.activation.zedSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (
          lib.hm.generators.mkImpureConfigMerger {
            inherit pkgs;
            format = "json";
            empty = "{}";
            jqOperation = "$static * $dynamic";
            path = settingsFile;
            staticSettings = (pkgs.formats.json { }).generate "zed-default-settings" defaultSettings;
            reader = "${lib.getExe json5} --as-json";
            verboseMsg = "Filling in missing Zed defaults in ${settingsFile}";
          }
        );

        # macOS: the `zed` cask (bundle id dev.zed.Zed). Failures aren't fatal so a
        # missing cask on first activation doesn't abort the switch.
        home.activation.zedFileAssociations = lib.mkIf isDarwin (
          lib.hm.dag.entryAfter [ "writeBoundary" ] (
            lib.concatMapStringsSep "\n" (
              a: "run ${lib.getExe pkgs.duti} -s dev.zed.Zed ${a.ext} all || true"
            ) associations
          )
        );

        # Linux
        xdg.mimeApps = lib.mkIf isLinux {
          enable = true;
          defaultApplications = lib.listToAttrs (
            map (a: lib.nameValuePair a.mime [ "dev.zed.Zed.desktop" ]) associations
          );
        };
      };
  };
}
