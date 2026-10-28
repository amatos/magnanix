{ inputs, ... }:
{
  den.hosts.aarch64-darwin.darwintron = {
    users.alberth = { };
    # Den's default darwin builder reads `inputs.darwin`; this flake names the
    # input `nix-darwin`.
    instantiate = inputs.nix-darwin.lib.darwinSystem;
  };

  # Configuration specific to darwintron
  den.aspects.darwintron = {
    darwin = {
      system.stateVersion = 7;
    };
  };
}
