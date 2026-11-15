# Ghostty

The `ghostty` aspect (`modules/packages/ghostty.nix`) installs [Ghostty](https://ghostty.org) through Home Manager.
Its config is written in Nix as `programs.ghostty.settings` and checked with `ghostty +validate-config` whenever it
changes. macOS uses `ghostty-bin` (the upstream app bundle), because `ghostty` doesn't build there.

## Where the config lives

| Platform | Config                                                                | Themes                     |
| -------- | --------------------------------------------------------------------- | -------------------------- |
| macOS    | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` | `~/.config/ghostty/themes` |
| Linux    | `~/.config/ghostty/config`                                            | `~/.config/ghostty/themes` |

On macOS Ghostty reads `~/.config/ghostty/config` and then the Application Support file, but Cmd+, (Settings)
opens the Application Support file whenever it exists, so the config is written there. The file is a read-only
symlink into the Nix store: change `modules/packages/ghostty.nix` and switch rather than editing it. The first
switch replaces the comments-only template Ghostty creates there (`force = true`), which would otherwise stop
activation.

Themes stay in `~/.config/ghostty/themes` on every platform: it's the only user directory Ghostty searches for a
theme named in `theme = …` (the other is the app's own bundled themes). A theme in Application Support would only
load by its absolute path.

## Changes from Ghostty's defaults

| Setting                            | Value                       | Why                                                                                     |
| ---------------------------------- | --------------------------- | --------------------------------------------------------------------------------------- |
| `theme`                            | `Dracula`                   | Ghostty's built-in Dracula; Dracula PRO is layered on top when available (see below)    |
| `font-size`                        | `14`                        | the default is 13                                                                       |
| `copy-on-select`                   | `clipboard`                 | selecting text also copies it to the system clipboard, so Cmd-V and other apps paste it |
| `middle-click-action`              | `clipboard-paste`           | middle-click pastes the system clipboard; the default does nothing on macOS             |
| `window-inherit-working-directory` | `false`                     | new windows start in `working-directory`, not the previous window's directory           |
| `working-directory`                | `home`                      | new windows start in the home directory however Ghostty was launched (see below)        |
| `shell-integration-features`       | `sudo,ssh-env,ssh-terminfo` | keeps Ghostty's terminfo under sudo and on remote hosts over SSH                        |

## Copy and paste with the mouse

Selecting text copies it to the system clipboard, and a middle-click pastes the clipboard into the terminal, so
select-then-middle-click works the same as on a Linux desktop. Ghostty's default middle-click action,
`primary-paste`, pastes from the selection clipboard; Linux has one, but macOS doesn't, so on macOS the default does
nothing. Because `copy-on-select = clipboard` copies to both clipboards, `clipboard-paste` behaves the same on every
host. Anything copied with Cmd-C (or Ctrl-Shift-C) also lands in the clipboard, so middle-click pastes whichever
was copied last.

## Starting directory

New windows start in the home directory. New tabs and splits keep Ghostty's default and start in the working
directory of the tab or split that was focused before (`tab-inherit-working-directory` and
`split-inherit-working-directory`, both `true` by default). `working-directory = home` is set explicitly because
Ghostty's own default is `home` only when it's launched from the Dock, Finder or a desktop launcher; launched from a
shell, it would be the directory Ghostty was started in.

## Dracula PRO

Users with `magnanix.draculaPro` enabled (see `modules/den/dracula-pro.nix`) get Dracula PRO's flagship colors
through an optional include (`config-file = ?…/themes/ghostty/pro`). The leading `?` means a host without the
checkout yet falls back to plain Dracula instead of failing. Every PRO variant is also linked into
`~/.config/ghostty/themes` as `dracula-pro-<variant>` (the flagship as `dracula-pro`), to try one by hand.

## Terminfo

`ghostty.terminfo` (included by `base`) installs Ghostty's terminfo system-wide on every NixOS and darwin host, so
hosts that don't run Ghostty can still serve SSH sessions coming from it.
