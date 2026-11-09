{ inputs, ... }:
{
  # Official Delta flake (Linux binaries only: x86_64-linux and aarch64-linux).
  # Follows our nixpkgs so Delta uses the host's glibc/graphics stack.
  flake-file.inputs.delta = {
    url = "github:zed-industries/delta-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

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
        # The checkout location comes from the shared `magnanix.repoDir` option.
        settingsFile = "${config.magnanix.repoDir}/modules/users/${config.home.username}/configs/zed/settings.json";

        # Zed's Delta (the AI coding assistant) installs its CLI as `bin/delta`, which
        # collides with the git pager `delta` that `programs.delta` (git.nix) installs.
        # Expose it as `zed-delta` (the name of its macOS cask) and leave `delta` to
        # the pager. Its desktop entries call the original store path, so they keep
        # working.
        zedDelta =
          let
            delta = inputs.delta.packages.${pkgs.stdenv.hostPlatform.system}.delta;
          in
          pkgs.runCommand "zed-delta-${delta.version}" { } ''
            mkdir -p $out/bin
            ln -s ${delta}/bin/delta $out/bin/zed-delta
            if [ -e ${delta}/bin/delta-app ]; then
              ln -s ${delta}/bin/delta-app $out/bin/delta-app
            fi
            ln -s ${delta}/share $out/share
          '';

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

        defaultSettingsFile = (pkgs.formats.json { }).generate "zed-default-settings" defaultSettings;

        mergeSettings = pkgs.writeShellScript "zed-merge-settings" ''
          set -euo pipefail
          export PATH=${lib.makeBinPath [ pkgs.coreutils ]}
          jq=${lib.getExe pkgs.jq}
          file=${lib.escapeShellArg settingsFile}
          defaults=${defaultSettingsFile}

          mkdir -p "$(dirname "$file")"

          if [[ ! -s "$file" ]]; then
            "$jq" . "$defaults" > "$file"
            exit 0
          fi

          # An existing file that fails to parse must fail activation rather
          # than be replaced by the defaults.
          if ! current="$(${lib.getExe json5} --as-json "$file")" || [[ -z "$current" ]]; then
            echo "Could not parse $file; refusing to merge." >&2
            exit 1
          fi

          merged="$("$jq" -n \
            --slurpfile defaults "$defaults" \
            --slurpfile current <(printf '%s' "$current") \
            '$defaults[0] * $current[0]')"

          # Compare semantically (sorted keys, compact) so formatting and key
          # order never count as a change. If the file already has every default,
          # leave it byte-for-byte untouched.
          if [[ "$("$jq" -cS . <<<"$merged")" == "$("$jq" -cS . <<<"$current")" ]]; then
            exit 0
          fi

          tmp="$(mktemp "$file.XXXXXX")"
          trap 'rm -f -- "$tmp"' EXIT
          "$jq" . <<<"$merged" > "$tmp"
          chmod --reference="$file" -- "$tmp"
          mv -f -- "$tmp" "$file"
        '';

        # Files to open with Zed. macOS (duti) associates by extension; Linux
        # (xdg.mimeApps) associates by MIME type.
        associations = [
          {
            ext = ".txt";
            mime = "text/plain";
          }
          {
            ext = ".yaml";
            mime = "application/yaml";
          }
          {
            ext = ".sh";
            mime = "application/x-shellscript";
          }
        ];
      in
      {
        # duti is macOS-only; on Linux Zed comes from nixpkgs and Delta from its
        # official flake (no casks there).
        home.packages =
          lib.optionals isDarwin [ pkgs.duti ]
          ++ lib.optionals isLinux [
            pkgs.zed-editor
            zedDelta
          ];

        # Use Zed for $VISUAL; --wait blocks until the file's tab is closed so
        # callers (git commit, crontab -e, …) see the edited result. On macOS the
        # cask links the `zed` CLI onto PATH; on Linux nixpkgs names it `zeditor`.
        home.sessionVariables.VISUAL =
          if isDarwin then "zed --wait" else "${lib.getExe pkgs.zed-editor} --wait";

        xdg.configFile."zed/settings.json".source = config.lib.file.mkOutOfStoreSymlink settingsFile;

        # Runs after the symlink exists. Creates the tracked file from the skeleton
        # if it's missing; otherwise fills in missing keys (file wins on conflicts).
        # The file is only rewritten when the merge actually adds something, so
        # Zed's own formatting (trailing commas, key order) survives a switch
        # and doesn't show up as a spurious git diff.
        #
        # Skipped, with a warning, when `magnanix.repoDir` isn't a git checkout (not
        # cloned yet, or cloned somewhere else). Creating the file there would leave
        # a stray directory holding one generated file, and the misplaced clone
        # would go unnoticed. Not fatal: a fresh install activates before the repo
        # is cloned.
        home.activation.zedSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          if [[ ! -e ${lib.escapeShellArg "${config.magnanix.repoDir}/.git"} ]]; then
            warnEcho ${lib.escapeShellArg "Skipping Zed settings: ${config.magnanix.repoDir} is not a git checkout, so ~/.config/zed/settings.json points nowhere. Clone magnanix there (or set magnanix.repoDir to where it is) and switch again."}
          elif [[ -v DRY_RUN ]]; then
            echo ${lib.escapeShellArg "Would fill in missing Zed defaults in ${settingsFile}"}
          else
            ${mergeSettings}
          fi
        '';

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
