{ ... }:
{
  # NOTE: assumes nixostron is x86_64-linux. Den sets nixpkgs.hostPlatform from
  # this key, so change it here if the machine is aarch64-linux.
  den.hosts.x86_64-linux.nixostron.users.alberth = { };

  # Configuration specific to nixostron (hardware-configuration.nix, boot loader,
  # filesystems, ...)
  den.aspects.nixostron = {
    nixos = {
      system.stateVersion = "26.05";
    };
  };
}
