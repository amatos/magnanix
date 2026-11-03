{ den, ... }:
{
  # Baseline configuration for every host.
  den.aspects.base = {
    # Sets the OS hostname from the Den host name, which must match
    # `scutil --get LocalHostName` (macOS) or `hostname` (NixOS).
    # The aspects below are shared by all hosts and their users.
    includes = [
      den.batteries.hostname

      den.aspects.cliutils
      den.aspects.darwin.customizations
      den.aspects.ghostty.terminfo
      den.aspects.imagemagick
      den.aspects.mail
      den.aspects.nix-tools
      den.aspects.nixosKernel # NixOS-only: defines just the `nixos` class
      den.aspects.nushell
      den.aspects.shell.bash
      den.aspects.shell.fish
      den.aspects.shell.zsh
      den.aspects.sudo
      den.aspects.tui.atuin
      den.aspects.tui.tealdeer
      den.aspects.tui.trash
      den.aspects.tui.yazi
      den.aspects.tui.yubikey
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
}
