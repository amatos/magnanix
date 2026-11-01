{ den, ... }:
{
  # Baseline configuration for every host.
  den.aspects.base = {
    # Sets the OS hostname from the Den host name, which must match
    # `scutil --get LocalHostName` (macOS) or `hostname` (NixOS).
    # The aspects below are shared by all hosts and their users.
    includes = [
      den.batteries.hostname

      den.aspects.darwin.customizations
      den.aspects.ghostty.terminfo
      den.aspects.nix-tools
      den.aspects.shell.bash
      den.aspects.shell.fish
      den.aspects.shell.zsh
      den.aspects.tui.atuin
      den.aspects.tui.trash
      den.aspects.tui.zoxide
    ];

    # Shared by all hosts (`os` lands in `darwin` on macOS and `nixos` on NixOS)
    os = { };

    # macOS-only baseline
    darwin = { };

    # NixOS-only baseline
    nixos = { };
  };

  den.default.includes = [ den.aspects.base ];
}
