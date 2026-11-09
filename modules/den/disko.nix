{ inputs, ... }:
{
  # disko: declarative disk partitioning. A host that includes this aspect describes
  # its disks with `disko.devices`; disko derives `fileSystems` from that, and
  # nixos-anywhere uses it to partition and format the disk on install. It also
  # provides `system.build.vmWithDisko`, a QEMU VM that boots the real layout.
  den.aspects.disko.nixos.imports = [ inputs.disko.nixosModules.disko ];

  flake-file.inputs.disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
