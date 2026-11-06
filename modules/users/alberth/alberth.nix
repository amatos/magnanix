{ den, ... }:
let
  # Defined here (rather than read back through `config`) so the same values can
  # be used both as aspect metadata and inside this aspect's own definitions,
  # including attribute names, without risking infinite recursion.
  meta = {
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILfxNl1S0Fvzh2aOAG6FuIwB96eqnUqY1nl2p2jSnTOD internal"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDkzNer1Wht+A3qapGFtp8LzrxamOWbfV1sP4J5lW8qI alberth@darwintron"
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

      den.aspects.alberth.macos.dock
      den.aspects.alberth.scripts
      den.aspects.alberth.shellAliases
      den.aspects.alberth.ssh
      den.aspects.direnv
      den.aspects.github
      den.aspects.gpg
      den.aspects.macos.mas
      den.aspects.macos.setapp
      den.aspects.macos.supaSideBar
      den.aspects.macos.spamsieve
      den.aspects.macos.skim
      den.aspects.rust
      den.aspects.ruby
      den.aspects.python
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
        # Only cloned on hosts with an app that uses it (Ghostty), not on muninn.
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
        # On NixOS this also overrides the fish default set by the shell.fish aspect.
        users.users.${meta.username}.shell = pkgs.zsh;
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

    # extraGroups, openssh and hashedPasswordFile are NixOS-only users.users options
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

          openssh.authorizedKeys.keys = meta.authorizedKeys;
        };
      };
  };
}
