# User:      alberth (den.aspects.alberth)
# Platforms: nixos, darwin, home-manager
# Purpose:   alberth's account, metadata and personal tool set: the language
#            toolchains, gpg, direnv, gh, the Dock, ~/.local/bin scripts,
#            deploy-magnanix and SSH client config. Follows alberth to every
#            host they're on.
#
# Notes:
# - `meta` (identity, SSH keys, GPG key) is read by shared aspects such as git
#   and gpg; see documentation/architecture.md for each attribute.
# - host-aspects forwards the homeManager parts of the host's apps into this
#   home; without it, host aspects only deliver their system-level config.
# - Login shell is Nix's zsh everywhere. macOS needs a dscl postActivation
#   script for this (see below); open a new terminal after the first switch.
# - ~/.ssh/authorized_keys is a real file (mode 600), not a store symlink,
#   because sshd's StrictModes rejects the group-writable store.
# - NixOS password: `alberth_password` (yescrypt hash) in secrets/common.yaml.
#   It always wins over `passwd`. macOS passwords are never managed here.
{ den, ... }:
let
  # Defined here (rather than read back through `config`) so the same values can
  # be used both as aspect metadata and inside this aspect's own definitions,
  # including attribute names, without risking infinite recursion.
  meta = {
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILfxNl1S0Fvzh2aOAG6FuIwB96eqnUqY1nl2p2jSnTOD internal"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDkzNer1Wht+A3qapGFtp8LzrxamOWbfV1sP4J5lW8qI alberth@darwintron"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIgWB6nLQXyN7qcb23zZt1Nd+4QuaXm78Ye39FnwgNaj IOSinternal@Prompt3"
    ];

    email = "alberth@matos.cc";
    fullName = "Alberth Matos";
    gpgKey = "F41BDBF6171A3BB4"; # ed25519/0xF41BDBF6171A3BB4
    gpgFingerprint = "5FC8FE1141FA769594E91E48F41BDBF6171A3BB4";
    gpgPublicKey = ./F41BDBF6171A3BB4.pub.asc;

    username = "alberth";
  };
in
{
  den.aspects.alberth = {
    inherit meta;

    # OS-level account (users.users.alberth with its home directory) plus
    # home.username / home.homeDirectory for Home Manager.
    includes = [
      den.batteries.define-user

      # Forwards the `homeManager` parts of the host's aspects (the apps listed in
      # each host file's `includes`) into alberth's home. Host aspects only
      # deliver their system-level config on their own.
      den.batteries.host-aspects

      den.aspects.alberth.deployMagnanix
      den.aspects.alberth.macos.dock
      den.aspects.alberth.scripts
      den.aspects.alberth.ssh
      den.aspects.c
      den.aspects.direnv
      den.aspects.elixir
      den.aspects.github
      den.aspects.go
      den.aspects.gpg
      den.aspects.javascript
      den.aspects.kotlin
      den.aspects.lua
      den.aspects.macos.appInspection
      den.aspects.macos.macMouseFix
      den.aspects.macos.mas
      den.aspects.macos.setapp
      den.aspects.macos.skim
      den.aspects.macos.spamsieve
      den.aspects.macos.supaSideBar
      den.aspects.ocaml
      den.aspects.php
      den.aspects.python
      den.aspects.ruby
      den.aspects.rust
      den.aspects.shellscript
      den.aspects.swift
      den.aspects.zig
    ];

    # Home Manager configuration for alberth
    homeManager =
      { lib, pkgs, ... }:
      {
        # Set to the release alberth's Home Manager was first set up with
        home.stateVersion = "26.05";

        home.packages = [ pkgs.htop ];

        # Licensed theme pack (see modules/den/dracula-pro.nix). Access comes from
        # alberth's GitHub account, so the URL alone gives nobody else anything.
        # Only cloned on hosts with an app that uses it (Ghostty), so headless hosts
        # never try.
        magnanix.draculaPro = {
          enable = true;
          repo = "git@github.com:dracula-pro/dracula-pro.git";
        };

        # A real file rather than home.file: that would be a symlink into /nix/store,
        # which sshd's StrictModes rejects because the store is group-writable.
        home.activation.authorizedKeys =
          let
            authorizedKeys = pkgs.writeText "authorized_keys" (lib.concatLines meta.authorizedKeys);
          in
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run mkdir -p "$HOME/.ssh"
            run chmod 700 "$HOME/.ssh"
            run install -m 600 ${authorizedKeys} "$HOME/.ssh/authorized_keys"
          '';
      };

    user = {
      createHome = true;
      description = meta.fullName;
    };

    # Login shell: Nix's zsh (not macOS's /bin/zsh). The zsh aspect enables
    # programs.zsh at system level, which this setting requires.
    os =
      { pkgs, ... }:
      {
        users.users.${meta.username} = {
          # On NixOS this also overrides the fish default set by the shell.fish aspect.
          shell = pkgs.zsh;

          # Keys that may log in as alberth over SSH, on hosts that include the
          # openssh aspect. nix-darwin puts them in /etc/ssh/nix_authorized_keys.d.
          openssh.authorizedKeys.keys = meta.authorizedKeys;
        };
      };

    # nix-darwin only applies users.users.<name>.shell to users in users.knownUsers,
    # and adding alberth there would make nix-darwin manage (and delete) the account.
    # So set the shell on the existing account after every activation instead, and
    # list it in /etc/shells (nix-darwin doesn't add programs.zsh to it), which
    # chsh and login require.
    darwin =
      { pkgs, ... }:
      {
        environment.shells = [ pkgs.zsh ];

        system.activationScripts.postActivation.text = ''
          if [ "$(dscl . -read /Users/${meta.username} UserShell)" != "UserShell: /run/current-system/sw/bin/zsh" ]; then
            echo "setting ${meta.username}'s login shell to Nix zsh..." >&2
            dscl . -create /Users/${meta.username} UserShell /run/current-system/sw/bin/zsh
          fi
        '';
      };

    # extraGroups and hashedPasswordFile are NixOS-only users.users options
    # (not supported by nix-darwin's users.users submodule).
    nixos =
      { config, ... }:
      {
        # Login password, the same on every NixOS host: a yescrypt hash
        # (`mkpasswd -m yescrypt`) under `alberth_password` in secrets/common.yaml.
        # neededForUsers decrypts it before the user accounts are created. base sets
        # users.mutableUsers = false, so this password wins over `passwd` changes.
        #
        # Never manage this password on macOS: nix-darwin has no password option, and
        # changing it with `dscl` breaks the login keychain and the FileVault token.
        sops.secrets.alberth_password = {
          sopsFile = ../../../secrets/common.yaml;
          neededForUsers = true;
        };

        users.users.${meta.username} = {
          extraGroups = [
            "dialout" # Or else: Permission denied: ‘/dev/ttyUSB0’
            "input"
            "tty"
          ];

          hashedPasswordFile = config.sops.secrets.alberth_password.path;
        };
      };
  };
}
