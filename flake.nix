# DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "magnanix: nix-darwin, NixOS and Home Manager on Determinate Nix";

  outputs =
    inputs:
    (inputs.nixpkgs.lib.evalModules {
      specialArgs = {
        inherit inputs;
        inherit (inputs) self;
      };
      modules = [ (inputs.import-tree ./modules) ];
    }).config.outputs
      inputs;

  inputs = {
    den = {
      url = "github:denful/den";
    };
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
      inputs = {
        nix.inputs.git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";
        nixpkgs.follows = "nixpkgs";
      };
    };
    flake-file = {
      url = "github:denful/flake-file";
    };
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree = {
      url = "github:denful/import-tree";
    };
    nix-darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };
    nixpkgs = {
      url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
