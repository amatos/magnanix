{ den, inputs, ... }:
{
  den.hosts.aarch64-darwin.magnus = {
    users.alberth = { };
    # Den's default darwin builder reads `inputs.darwin`; this flake names the
    # input `nix-darwin`.
    instantiate = inputs.nix-darwin.lib.darwinSystem;
  };

  # Configuration specific to magnus
  den.aspects.magnus = {
    # System-level apps for this machine. Users that include
    # `den.batteries.host-aspects` also get the `homeManager` parts of these.
    includes = [
      den.aspects._1password
      den.aspects.browsers
      den.aspects.claude
      den.aspects.fonts
      den.aspects.ghostty
      den.aspects.audio
      den.aspects.macos.orbstack
      den.aspects.steam
      den.aspects.tex
      den.aspects.tui.macos.tart
      den.aspects.zed
      den.aspects.zsa.voyager
    ];

    darwin = {
      system.stateVersion = 7;
    };
  };

  # alberth is the primary user on magnus.
  den.aspects.magnus.provides.alberth.includes = [ den.batteries.primary-user ];
}
