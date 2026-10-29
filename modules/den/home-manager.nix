{
  inputs,
  lib,
  ...
}:
{
  # Unstable Home Manager (master; use 0 for stable)
  flake-file.inputs.home-manager = {
    url = "https://flakehub.com/f/nix-community/home-manager/0.1";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Every user gets Home Manager. Den imports home-manager's NixOS/nix-darwin
  # module itself (from inputs.home-manager) on hosts with such users, and
  # merges each user's `homeManager` class into home-manager.users.<name>.
  den.schema.user.classes = lib.mkDefault [ "homeManager" ];

  # Applied to every host that enables Home Manager.
  den.schema.hm-host.includes = [
    (
      { host, ... }:
      {
        ${host.class}.home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit inputs;
          };
        };
      }
    )
  ];
}
