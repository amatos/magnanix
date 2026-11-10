# Aspect:    den.aspects.disko (opt-in)
# Platforms: nixos
# Purpose:   Imports disko so a host can declare its partitions, filesystems and
#            LUKS devices in Nix (`disko.devices`) and have them created at
#            install time by disko or nixos-anywhere.
{ inputs, ... }:
{
  # disko: declarative disk partitioning. A host that includes this aspect describes
  # its disks with `disko.devices`; disko derives `fileSystems`, `swapDevices` and
  # `boot.initrd.luks.devices` from that, and its CLI (or nixos-anywhere) partitions
  # and formats the disks on install. It also provides `system.build.vmWithDisko`, a
  # QEMU VM that boots the real layout.
  #
  # Only list the disks a host owns. Running disko wipes every disk it declares.
  den.aspects.disko.nixos.imports = [ inputs.disko.nixosModules.disko ];

  flake-file.inputs.disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
