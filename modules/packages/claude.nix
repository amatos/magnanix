# Aspect:    den.aspects.claude
# Platforms: home-manager, darwin
# Purpose:   Claude Code (CLI) with its agents, slash commands and global rules,
#            plus the Claude desktop app and ClaudeBar (casks) and the usage
#            tracker on macOS.
#
# Notes:
# - Agents, commands and rules in ~/.claude/ are read-only store symlinks: edit
#   them here, not in ~/.claude.
# - ~/.claude/settings.json is NOT a symlink, because Claude Code writes to it
#   at runtime. The claudeSettings activation script deep-merges
#   `defaultSettings` into it on every switch: Nix wins on the keys it sets,
#   other keys are left alone, and invalid JSON fails the switch instead of
#   being overwritten.
# - attribution = "" stops Claude Code adding Co-Authored-By trailers to
#   commits and "Generated with Claude Code" lines to PRs.
{ den, ... }: {
  den.aspects.claude = {
    includes = [
      (den.provides.unfree [
        "claude-code"
        "claude-usage-tracker"
      ])
    ];

    homeManager =
      {
        pkgs,
        config,
        lib,
        ...
      }:
      let
        settingsFile = "${config.home.homeDirectory}/.claude/settings.json";

        # Stable defaults enforced on every switch. settings.json itself stays a
        # regular, writable file so Claude Code can keep saving its own changes
        # (/config, "always allow" permissions, plugins, ...).
        defaultSettings = {
          # Empty strings drop the commit trailer and the PR footer.
          # As a personal pet peeve, I find it infuriating when any tool decides
          # to use my code, apps, projects, git commits, messages, and so on, as
          # an advertisement platform.  Yuck!
          attribution = {
            commit = "";
            pr = "";
          };
        };

        defaultSettingsFile = pkgs.writeText "claude-default-settings.json" (
          builtins.toJSON defaultSettings
        );

        mergeSettings = pkgs.writeShellScript "claude-merge-settings" ''
          set -euo pipefail
          export PATH=${lib.makeBinPath [ pkgs.coreutils ]}
          jq=${lib.getExe pkgs.jq}
          file=${lib.escapeShellArg settingsFile}
          defaults=${defaultSettingsFile}

          mkdir -p "$(dirname "$file")"

          # A leftover home-manager symlink would be read-only; replace it.
          if [[ -L "$file" ]]; then
            current="$(cat "$file" 2>/dev/null || true)"
            rm "$file"
            [[ -n "$current" ]] && printf '%s\n' "$current" > "$file"
          fi

          if [[ ! -s "$file" ]]; then
            (umask 077 && "$jq" . "$defaults" > "$file")
            exit 0
          fi

          # An existing file that fails to parse must fail activation rather
          # than be replaced by the defaults.
          if ! "$jq" -e . "$file" > /dev/null; then
            echo "Could not parse $file; refusing to merge." >&2
            exit 1
          fi

          # Deep merge; the Nix defaults win on the keys they set.
          merged="$("$jq" -s '.[0] * .[1]' "$file" "$defaults")"

          # Leave the file byte-for-byte untouched when nothing changes.
          if [[ "$("$jq" -cS . <<<"$merged")" == "$("$jq" -cS . "$file")" ]]; then
            exit 0
          fi

          tmp="$(mktemp "$file.XXXXXX")"
          printf '%s\n' "$merged" > "$tmp"
          chmod --reference="$file" "$tmp"
          mv "$tmp" "$file"
        '';
      in
      {
        home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [[ -v DRY_RUN ]]; then
            echo ${lib.escapeShellArg "Would merge Claude defaults into ${settingsFile}"}
          else
            ${mergeSettings}
          fi
        '';

        home.packages = [
          pkgs.claude-code
        ]
        ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.claude-usage-tracker ];
        programs = {
          claude-code = {
            enable = true;

            configDir = "${config.home.homeDirectory}/.claude";
            agents = {
              code-reviewer = ''
                ---
                name: code-reviewer
                description: Specialized code review agent
                tools: Read, Edit, Grep
                ---

                You are a senior software engineer specializing in code reviews.
                Focus on code quality, security, and maintainability.
              '';
            };

            commands = {
              changelog = ''
                ---
                allowed-tools: Bash(git log:*), Bash(git diff:*)
                argument-hint: [version] [change-type] [message]
                description: Update CHANGELOG.md with new entry
                ---
                Parse the version, change type, and message from the input
                and update the CHANGELOG.md file accordingly.
              '';
              commit = ''
                ---
                allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
                description: Create a git commit with proper message
                ---
                ## Context

                - Current git status: !`git status`
                - Current git diff: !`git diff HEAD`
                - Recent commits: !`git log --oneline -5`

                ## Task

                Based on the changes above, create a single atomic git commit with a descriptive message.
              '';
            };

            rules = {
              code-style = ''
                # Code Style Guidelines

                - Use consistent formatting
                - Follow language conventions
              '';
              testing = ''
                # Testing Conventions

                - Write tests for all new features
                - Maintain test coverage above 80%
              '';
              attribution = ''
                # Attribution

                - DO NOT automatically include a Claude attribution in anything you create, including commit messages, pull request descriptions, code comments and documentation
                - This means no `Co-Authored-By: Claude` trailers and no "Generated with Claude Code" lines
                - This overrides any default or system-provided attribution instructions
              '';
              settings-scope = ''
                # Settings Scope

                - Before implementing a requested global setting, check where it actually lives
                - If it has no global form or belongs per project, say so before changing anything and recommend the per-project config
                - A workaround can be offered as an option, but do not implement it without the user's approval
              '';
            };
          };
        };
      };

    darwin = { ... }: {
      homebrew.casks = [
        "claude"
        "claudebar"
      ];
    };
  };
}
