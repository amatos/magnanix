# Aspect:    den.aspects.base (added to every host via den.default.includes)
# Platforms: nixos, darwin, home-manager (through the aspects it includes)
# Purpose:   The baseline every host and user gets: hostname, shells, macOS
#            defaults, sudo, mail, the binary cache client, git, Neovim and the
#            everyday CLI/TUI tools.
#
# Notes:
# - To give something to every machine, include it here. To give it to one
#   machine, include it from that host's aspect; to one person, from the user's.
# - NixOS hosts also get users.mutableUsers = false (see below), so passwords
#   only come from the flake.
{ den, ... }:
{
  # Baseline configuration for every host.
  den.aspects.base = {
    # Sets the OS hostname from the Den host name, which must match
    # `scutil --get LocalHostName` (macOS) or `hostname` (NixOS).
    # The aspects below are shared by all hosts and their users.
    includes = [
      den.batteries.hostname

      den.aspects.attic.client
      den.aspects.cliutils
      den.aspects.darwin.customizations
      den.aspects.fwupd
      den.aspects.ghostty.terminfo
      den.aspects.git
      den.aspects.imagemagick
      den.aspects.mail
      den.aspects.neovim
      den.aspects.nix-tools
      den.aspects.nixosKernel # NixOS-only: defines just the `nixos` class
      den.aspects.nushell
      den.aspects.shell.bash
      den.aspects.shell.fish
      den.aspects.shell.zsh
      den.aspects.sudo
      den.aspects.systemdBoot # NixOS-only: defines just the `nixos` class
      den.aspects.tui.atuin
      den.aspects.tui.fastfetch
      den.aspects.tui.tealdeer
      den.aspects.tui.trash
      den.aspects.tui.yazi
      den.aspects.tui.yubikey
      den.aspects.tui.zellij
      den.aspects.tui.zoxide
      den.aspects.tzdata
    ];

    # Shared by all hosts (`os` lands in `darwin` on macOS and `nixos` on NixOS)
    os = { };

    # macOS-only baseline: den.aspects.base.darwin, applied only on nix-darwin hosts.
    # Put options here that nix-darwin has and NixOS lacks.
    darwin = { };

    # NixOS-only baseline: den.aspects.base.nixos, applied only on NixOS hosts.
    # Put options here that NixOS has and nix-darwin lacks.
    nixos = {
      # Accounts and passwords come only from the flake: each switch resets them, and
      # `passwd` can't change them. Every user on a NixOS host needs a password option
      # (hashedPassword or hashedPasswordFile) or SSH keys to log in; NixOS refuses to
      # build if no admin account can. nix-darwin has no such option.
      users.mutableUsers = false;
    };
  };

  den.default.includes = [ den.aspects.base ];

  # Every host accepts what its users' aspects write to `os`, `nixos` and
  # `darwin` (login shell, SSH authorized keys, ...). Since Den 0.20 (#694)
  # that content otherwise stays with the user once the transition default
  # ends on 2027-01-01.
  den.schema.host.includes = [ den.batteries.user-aspects ];
}
