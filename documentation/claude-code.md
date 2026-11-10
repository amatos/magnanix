# Claude Code

The `claude` feature (`modules/packages/claude.nix`) installs Claude Code and configures it
through Home Manager's `programs.claude-code`. The agents, slash commands and global rules in `~/.claude/` are
symlinks into the store, so edit them in the module.

`~/.claude/settings.json` is not managed that way, because Claude Code writes to it at runtime (`/config`, "always
allow" permissions, plugins) and a store symlink would be read-only. Instead, an activation script
(`home.activation.claudeSettings`) deep-merges `defaultSettings` into the file on every switch:

- The Nix values win on the keys they set; every other key in the file is left alone.
- A missing file is created (mode `600`), and the file isn't rewritten when nothing changes.
- A file that isn't valid JSON fails the switch rather than being overwritten.

`defaultSettings` currently sets `attribution` to empty strings, which stops Claude Code adding a `Co-Authored-By`
trailer to commits and a "Generated with Claude Code" line to pull requests (`includeCoAuthoredBy` is the deprecated
form). Settings changed this way apply to new Claude Code sessions. There's no user-level `settings.local.json`; that
file only works per project, in `<repo>/.claude/`.
