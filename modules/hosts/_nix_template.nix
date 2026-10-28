{ ... }:
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
}
