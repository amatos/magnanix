{ inputs, ... }:
{
  den.hosts.aarch64-darwin.CHANGE_HOSTNAME = {
    users.CHANGE_USERNAME = { };
    # Den's default darwin builder reads `inputs.darwin`; this flake names the
    # input `nix-darwin`.
    instantiate = inputs.nix-darwin.lib.darwinSystem;
  };

  # Configuration specific to CHANGE_HOSTNAME
  den.aspects.CHANGE_HOSTNAME = {
    darwin = {
      system.stateVersion = 7;
    };
  };
}
