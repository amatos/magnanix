{ den, ... }:
{
  # NOTE: assumes CHANGE_HOSTNAME is x86_64-linux. Den sets nixpkgs.hostPlatform from
  # this key, so change it here if the machine is aarch64-linux.
  den.hosts.x86_64-linux.CHANGE_HOSTNAME.users.CHANGE_USERNAME = { };

  # Configuration specific to CHANGE_HOSTNAME (hardware-configuration.nix, boot loader,
  # filesystems, ...)
  den.aspects.CHANGE_HOSTNAME = {
    nixos = {
      system.stateVersion = "26.05";
    };
  };

  # CHANGE_USERNAME is the primary user on CHANGE_HOSTNAME (system.primaryUser on macOS, wheel on NixOS).
  den.aspects.CHANGE_HOSTNAME.provides.CHANGE_USERNAME.includes = [ den.batteries.primary-user ];
}
