{ inputs, ... }:
{
  den.hosts.aarch64-darwin.magnus = {
    users.alberth = { };
    # Den's default darwin builder reads `inputs.darwin`; this flake names the
    # input `nix-darwin`.
    instantiate = inputs.nix-darwin.lib.darwinSystem;
  };

  # Configuration specific to magnus
  den.aspects.magnus = {
    darwin = {
      system.stateVersion = 7;
    };
  };
}
