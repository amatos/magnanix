{ inputs, ... }:
{
  # disko: declarative disk partitioning. A host that includes this aspect
  # describes its disks under `disko.devices`; disko then generates the matching
  # `fileSystems`, `swapDevices` and `boot.initrd.luks.devices`, and its CLI
  # partitions and formats the disks at install time.
  #
  # Only list the disks a host owns. Running disko wipes every disk it declares.
  den.aspects.disko.nixos.imports = [ inputs.disko.nixosModules.disko ];

  flake-file.inputs.disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
