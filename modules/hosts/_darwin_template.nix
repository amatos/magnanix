{ den, inputs, ... }:
{
  den.hosts.aarch64-darwin.CHANGE_HOSTNAME = {
    users.CHANGE_USERNAME = { };
    # Den's default darwin builder reads `inputs.darwin`; this flake names the
    # input `nix-darwin`.
    instantiate = inputs.nix-darwin.lib.darwinSystem;
  };

  # Configuration specific to CHANGE_HOSTNAME
  den.aspects.CHANGE_HOSTNAME = {
    includes = [
      den.aspects._1password
      den.aspects.browsers
      den.aspects.fonts
      den.aspects.ghostty
      den.aspects.openssh
      den.aspects.audio
      den.aspects.zed
    ];

    darwin = {
      system.stateVersion = 7;
    };
  };

  # CHANGE_USERNAME is the primary user on CHANGE_HOSTNAME (system.primaryUser on macOS, wheel on NixOS).
  den.aspects.CHANGE_HOSTNAME.provides.CHANGE_USERNAME.includes = [ den.batteries.primary-user ];
}
