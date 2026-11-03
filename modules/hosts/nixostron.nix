{ den, ... }:
{
  # NOTE: assumes nixostron is x86_64-linux. Den sets nixpkgs.hostPlatform from
  # this key, so change it here if the machine is aarch64-linux.
  den.hosts.x86_64-linux.nixostron.users.ephemeral = { };

  # Configuration specific to nixostron (hardware-configuration.nix, boot loader,
  # filesystems, ...)
  den.aspects.nixostron = {
    includes = [
      den.aspects.systemdBoot
    ];

    nixos = {
      system.stateVersion = "26.05";
    };
  };

  # ephemeral is the primary user on nixostron (system.primaryUser on macOS, wheel on NixOS).
  den.aspects.nixostron.provides.ephemeral.includes = [ den.batteries.primary-user ];
}
